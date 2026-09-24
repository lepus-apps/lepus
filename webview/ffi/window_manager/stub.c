/*
 * Window-manager runtime (g_wm, IPC, window lifecycle, platform view control)
 * — extracted from webview/stub.c as a pure mechanical move, zero logic change.
 *
 * Split out of the webview package into its own small FFI package
 * (`ffi/window_manager`). Shares the platform preamble and webview.h forward
 * declarations via ../common/c_abi.h.
 */
#include "../common/c_abi.h"


/* ── 枚举类型 ─────────────────────────────────────────────────── */

typedef enum
{
    WINDOW_STATE_CREATED = 0,
    WINDOW_STATE_RUNNING = 1,
    WINDOW_STATE_HIDDEN = 2,
    WINDOW_STATE_CLOSING = 3,
    WINDOW_STATE_CLOSED = 4
} window_state_t;

typedef enum
{
    PROCESS_TYPE_MAIN = 0,
    PROCESS_TYPE_CHILD = 1
} process_type_t;

typedef enum
{
    IPC_MSG_DATA = 0,
    IPC_MSG_COMMAND = 1,
    IPC_MSG_EVENT = 2,
    IPC_MSG_REQUEST = 3,
    IPC_MSG_RESPONSE = 4
} ipc_msg_type_t;

typedef enum
{
    WINDOW_EVT_CREATED = 0,
    WINDOW_EVT_SHOWN = 1,
    WINDOW_EVT_HIDDEN = 2,
    WINDOW_EVT_FOCUSED = 3,
    WINDOW_EVT_BLURRED = 4,
    WINDOW_EVT_CLOSING = 5,
    WINDOW_EVT_CLOSED = 6,
    WINDOW_EVT_RESIZED = 7,
    WINDOW_EVT_MOVED = 8
} window_evt_t;

typedef enum
{
    IPC_CONN_DISCONNECTED = 0,
    IPC_CONN_CONNECTING = 1,
    IPC_CONN_CONNECTED = 2,
    IPC_CONN_ERROR = 3
} ipc_conn_state_t;

/* ── 常量 ─────────────────────────────────────────────────────── */

#define IPC_MAGIC 0x4D425657u    /* "MBVW" */
#define IPC_MAX_DATA (64 * 1024) /* 每条消息最大 64 KB 数据 */
#define IPC_SUBTYPE_LEN 64
#ifdef _WIN32
#define IPC_SOCKET_PATH "tcp://127.0.0.1"
#define IPC_ENDPOINT_ENV "MOONBIT_WEBVIEW_IPC_PORT"
#else
#define IPC_SOCKET_PATH "/tmp/moonbit_webview_ipc.sock"
#endif
#define IPC_LISTEN_BACKLOG 16

/* ── IPC 消息结构 ─────────────────────────────────────────────── */

/* 线上协议帧头（定长，紧随变长 data） */
typedef struct
{
    uint32_t magic;
    int32_t total_length; /* sizeof(ipc_frame_hdr_t) + data_length */
    int32_t source_window_id;
    int32_t target_window_id;
    int32_t message_type;
    int32_t message_id;
    int32_t flags;
    char subtype[IPC_SUBTYPE_LEN];
} ipc_frame_hdr_t;

/* 内存中完整消息（包含数据缓冲区） */
typedef struct
{
    int32_t source_window_id;
    int32_t target_window_id;
    ipc_msg_type_t message_type;
    char subtype[IPC_SUBTYPE_LEN];
    char *data; /* 堆分配；NULL 表示无数据 */
    int32_t data_length;
    int32_t message_id;
    int32_t flags;
} ipc_message_t;

/* ── 窗口节点 ─────────────────────────────────────────────────── */

typedef struct webview_window
{
    int32_t window_id;
    webview_t handle;
    process_type_t process_type;
    pid_t process_id;
    window_state_t state;
    char title[256];
    int32_t width, height;
    int32_t x, y;
    int32_t hints;
    int32_t debug_mode;
    char url[1024];
    int32_t visible;
    int32_t fullscreen;
    int32_t is_child_process;
    int32_t parent_window_id;
    socket_handle_t ipc_client_fd; /* 主进程侧：已接受的客户连接 fd */
    ipc_conn_state_t ipc_state;
    void *user_data;
    /* 事件回调（可为 NULL） */
    void (*on_event)(struct webview_window *, window_evt_t, void *);
    struct webview_window *next;
    struct webview_window *prev;
} webview_window_t;

/* ── 窗口管理器 ───────────────────────────────────────────────── */

typedef struct
{
    webview_window_t *head;
    webview_window_t *tail;
    int32_t window_count;
    int32_t next_window_id;
    pthread_mutex_t mutex;
    /* IPC 服务器（主进程） */
    socket_handle_t ipc_socket;
    char ipc_socket_path[256];
    int ipc_server_running;
    pthread_t ipc_thread;
    /* 状态标志 */
    int initialized;
    process_type_t process_type;
    pid_t main_process_id;
    /* 全局回调（可为 NULL） */
    void (*on_window_created)(webview_window_t *);
    void (*on_window_destroyed)(int32_t window_id);
    void (*on_ipc_message)(ipc_message_t *);
    /* 请求-响应等待支持 */
    ipc_message_t *pending_response;
    int32_t pending_msg_id;
    pthread_cond_t response_cond;
    pthread_mutex_t response_mutex;
    pthread_mutex_t request_mutex;
    /* 全局消息序号 */
    int32_t next_message_id;
} window_manager_t;

static window_manager_t g_wm = {
    .head = NULL,
    .tail = NULL,
    .window_count = 0,
    .next_window_id = 1,
    .mutex = PTHREAD_MUTEX_INITIALIZER,
    .ipc_socket = IPC_INVALID_SOCKET,
    .ipc_socket_path = IPC_SOCKET_PATH,
    .ipc_server_running = 0,
    .ipc_thread = 0,
    .initialized = 0,
    .process_type = PROCESS_TYPE_MAIN,
    .main_process_id = -1,
    .on_window_created = NULL,
    .on_window_destroyed = NULL,
    .on_ipc_message = NULL,
    .pending_response = NULL,
    .pending_msg_id = -1,
    .response_cond = PTHREAD_COND_INITIALIZER,
    .response_mutex = PTHREAD_MUTEX_INITIALIZER,
    .request_mutex = PTHREAD_MUTEX_INITIALIZER,
    .next_message_id = 1};

static int g_macos_default_menu_enabled = 1;

/* ── IPC 子进程客户端 ─────────────────────────────────────────── */

typedef struct
{
    socket_handle_t socket_fd;
    int32_t window_id;
    int connected;
    pthread_t listener_thread;
    int32_t message_seq;
    ipc_conn_state_t state;
} ipc_client_t;

static ipc_client_t g_ipc_client = {
    .socket_fd = IPC_INVALID_SOCKET,
   .window_id = -1,
    .connected = 0,
    .listener_thread = 0,
    .message_seq = 0,
    .state = IPC_CONN_DISCONNECTED};

static socket_handle_t *g_remote_window_fds = NULL;
static int g_remote_window_fds_capacity = 0;

static void ensure_remote_window_fds_capacity_locked(int window_id)
{
    if (window_id < 0)
        return;
    if (window_id < g_remote_window_fds_capacity)
        return;
    int new_cap = g_remote_window_fds_capacity == 0 ? 32 : g_remote_window_fds_capacity * 2;
    while (new_cap <= window_id)
        new_cap *= 2;
    socket_handle_t *new_fds =
        (socket_handle_t *)realloc(g_remote_window_fds, (size_t)new_cap * sizeof(socket_handle_t));
    if (!new_fds)
        return;
    for (int i = g_remote_window_fds_capacity; i < new_cap; i++)
        new_fds[i] = IPC_INVALID_SOCKET;
    g_remote_window_fds = new_fds;
    g_remote_window_fds_capacity = new_cap;
}

static void set_remote_window_fd(int window_id, socket_handle_t fd)
{
    pthread_mutex_lock(&g_wm.mutex);
    ensure_remote_window_fds_capacity_locked(window_id);
    if (window_id >= 0 && window_id < g_remote_window_fds_capacity)
        g_remote_window_fds[window_id] = fd;
    pthread_mutex_unlock(&g_wm.mutex);
}

static socket_handle_t get_remote_window_fd(int window_id)
{
    pthread_mutex_lock(&g_wm.mutex);
    socket_handle_t fd =
        (window_id >= 0 && window_id < g_remote_window_fds_capacity) ? g_remote_window_fds[window_id] : IPC_INVALID_SOCKET;
    pthread_mutex_unlock(&g_wm.mutex);
    return fd;
}

static void clear_remote_window_fd(int window_id)
{
    pthread_mutex_lock(&g_wm.mutex);
    if (window_id >= 0 && window_id < g_remote_window_fds_capacity)
        g_remote_window_fds[window_id] = IPC_INVALID_SOCKET;
    pthread_mutex_unlock(&g_wm.mutex);
}

#ifdef __APPLE__
static void moonbit_macos_install_default_menu(void);
static void moonbit_macos_clear_main_menu(void);
#endif

/* 前向声明：供较早的辅助函数使用。 */
static int wm_dispatch(
    int window_id,
    void (*fn)(webview_t, void *),
    void *arg);
MOONBIT_FFI_EXPORT int moonbit_wm_get_process_id(void);
static void ipc_recv_callback(ipc_message_t *msg);

/* ════════════════════════════════════════════════════════════════
   内部辅助函数
   ════════════════════════════════════════════════════════════════ */

static char *dup_cstr(const char *src)
{
    size_t len = src ? strlen(src) : 0;
    char *copy = (char *)malloc(len + 1);
    if (!copy)
        return NULL;
    if (len > 0)
        memcpy(copy, src, len);
    copy[len] = '\0';
    return copy;
}

typedef struct
{
    char *js;
} eval_js_ctx_t;

static void eval_js_trampoline(webview_t handle, void *arg)
{
    eval_js_ctx_t *ctx = (eval_js_ctx_t *)arg;
    webview_eval(handle, ctx->js);
    free(ctx->js);
    free(ctx);
}

typedef struct
{
    char *seq;
    int status;
    char *result;
} return_raw_ctx_t;

static void return_raw_trampoline(webview_t handle, void *arg)
{
    return_raw_ctx_t *ctx = (return_raw_ctx_t *)arg;
    webview_return(handle, ctx->seq, ctx->status, ctx->result);
    free(ctx->seq);
    free(ctx->result);
    free(ctx);
}

/* 通过 window_id 查找窗口节点（需在锁外调用，或已持有锁） */
static webview_window_t *find_window(int32_t id)
{
    webview_window_t *w = g_wm.head;
    while (w)
    {
        if (w->window_id == id)
            return w;
        w = w->next;
    }
    return NULL;
}

/* 通过进程 PID 查找窗口节点 */
UNUSED_ATTR static webview_window_t *find_window_by_pid(pid_t pid)
{
    webview_window_t *w = g_wm.head;
    while (w)
    {
        if (w->process_id == pid)
            return w;
        w = w->next;
    }
    return NULL;
}

/* 生成唯一窗口 ID */
static int32_t alloc_window_id(void)
{
    pthread_mutex_lock(&g_wm.mutex);
    int32_t id = g_wm.next_window_id++;
    pthread_mutex_unlock(&g_wm.mutex);
    return id;
}

/* 生成唯一消息 ID */
static int32_t alloc_message_id(void)
{
    pthread_mutex_lock(&g_wm.mutex);
    int32_t id = g_wm.next_message_id++;
    pthread_mutex_unlock(&g_wm.mutex);
    return id;
}

/* 将窗口节点插入链表尾部 */
static void wm_add(webview_window_t *w)
{
    pthread_mutex_lock(&g_wm.mutex);
    w->next = NULL;
    w->prev = g_wm.tail;
    if (g_wm.tail)
        g_wm.tail->next = w;
    else
        g_wm.head = w;
    g_wm.tail = w;
    g_wm.window_count++;
    pthread_mutex_unlock(&g_wm.mutex);
}

/* 从链表中摘除窗口节点（不释放内存） */
static void wm_remove(webview_window_t *w)
{
    pthread_mutex_lock(&g_wm.mutex);
    if (w->prev)
        w->prev->next = w->next;
    else
        g_wm.head = w->next;
    if (w->next)
        w->next->prev = w->prev;
    else
        g_wm.tail = w->prev;
    g_wm.window_count--;
    pthread_mutex_unlock(&g_wm.mutex);
}

/* 触发窗口事件回调 */
static void fire_window_event(webview_window_t *w, window_evt_t evt, void *data)
{
    if (w && w->on_event)
        w->on_event(w, evt, data);
}

/* 触发 IPC 消息回调 */
static void fire_ipc_message(ipc_message_t *msg)
{
    if (g_wm.on_ipc_message)
        g_wm.on_ipc_message(msg);
}

/* 释放 ipc_message_t 中的堆数据 */
static void ipc_message_free(ipc_message_t *msg)
{
    if (msg && msg->data)
    {
        free(msg->data);
        msg->data = NULL;
        msg->data_length = 0;
    }
}

/* ════════════════════════════════════════════════════════════════
   IPC 低层 I/O：带重试的全量读/写
   ════════════════════════════════════════════════════════════════ */

/* 向 fd 写入 len 字节，自动处理 EINTR/EAGAIN；失败返回 -1 */
static int write_all(socket_handle_t fd, const void *buf, int len)
{
    const char *p = (const char *)buf;
    int remaining = len;
    while (remaining > 0)
    {
        int n = (int)send(fd, p, remaining, 0);
        if (n < 0)
        {
            int err = socket_last_error();
            if (socket_interrupted(err))
                continue;
            if (socket_would_block(err))
            {
                /* 轮询等待 1ms */
                struct timespec ts = {0, 1000000};
                nanosleep(&ts, NULL);
                continue;
            }
            return -1;
        }
        p += n;
        remaining -= n;
    }
    return len;
}

/* 从 fd 精确读取 len 字节，自动处理 EINTR；连接关闭或错误返回 -1 */
static int read_exact(socket_handle_t fd, void *buf, int len)
{
    char *p = (char *)buf;
    int remaining = len;
    while (remaining > 0)
    {
        int n = (int)recv(fd, p, remaining, 0);
        if (n < 0)
        {
            int err = socket_last_error();
            if (socket_interrupted(err))
                continue;
            if (socket_would_block(err))
            {
                struct timespec ts = {0, 1000000};
                nanosleep(&ts, NULL);
                continue;
            }
            return -1;
        }
        if (n == 0)
            return -1; /* 对端关闭 */
        p += n;
        remaining -= n;
    }
    return len;
}

/* ════════════════════════════════════════════════════════════════
   IPC 消息序列化 / 反序列化
   ════════════════════════════════════════════════════════════════ */

/* 将 ipc_message_t 序列化为帧并写入 fd；成功返回 0 */
static int ipc_send(socket_handle_t fd, const ipc_message_t *msg)
{
    int32_t data_len = msg->data ? msg->data_length : 0;
    ipc_frame_hdr_t hdr;
    memset(&hdr, 0, sizeof(hdr));
    hdr.magic = IPC_MAGIC;
    hdr.total_length = (int32_t)(sizeof(ipc_frame_hdr_t) + data_len);
    hdr.source_window_id = msg->source_window_id;
    hdr.target_window_id = msg->target_window_id;
    hdr.message_type = msg->message_type;
    hdr.message_id = msg->message_id;
    hdr.flags = msg->flags;
    strncpy(hdr.subtype, msg->subtype, IPC_SUBTYPE_LEN - 1);

    if (write_all(fd, &hdr, sizeof(hdr)) < 0)
        return -1;
    if (data_len > 0 && write_all(fd, msg->data, data_len) < 0)
        return -1;
    return 0;
}

/* 从 fd 读取一条消息并填充 *out（data 字段堆分配，调用方负责释放）；失败返回 -1 */
static int ipc_recv(socket_handle_t fd, ipc_message_t *out)
{
    ipc_frame_hdr_t hdr;
    if (read_exact(fd, &hdr, sizeof(hdr)) < 0)
        return -1;
    if (hdr.magic != IPC_MAGIC)
    {
        fprintf(stderr, "[IPC] bad magic 0x%08X\n", hdr.magic);
        return -1;
    }

    memset(out, 0, sizeof(*out));
    out->source_window_id = hdr.source_window_id;
    out->target_window_id = hdr.target_window_id;
    out->message_type = (ipc_msg_type_t)hdr.message_type;
    out->message_id = hdr.message_id;
    out->flags = hdr.flags;
    strncpy(out->subtype, hdr.subtype, IPC_SUBTYPE_LEN - 1);

    int32_t data_len = hdr.total_length - (int32_t)sizeof(ipc_frame_hdr_t);
    out->data_length = data_len;
    if (data_len > 0)
    {
        if (data_len > IPC_MAX_DATA)
        {
            fprintf(stderr, "[IPC] message too large: %d bytes\n", data_len);
            return -1;
        }
        out->data = (char *)malloc(data_len + 1);
        if (!out->data)
            return -1;
        if (read_exact(fd, out->data, data_len) < 0)
        {
            free(out->data);
            out->data = NULL;
            return -1;
        }
        out->data[data_len] = '\0';
    }
    return 0;
}

/* ════════════════════════════════════════════════════════════════
   IPC 服务器（主进程）
   ════════════════════════════════════════════════════════════════ */

/* 每个客户端连接的上下文 */
typedef struct
{
    socket_handle_t client_fd;
    int32_t remote_window_id; /* 握手后从第一条消息获取 */
    pthread_t thread;
} ipc_conn_ctx_t;

/* 路由消息到目标窗口的子进程连接 */
static void route_message(ipc_message_t *msg)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *target = find_window(msg->target_window_id);
    socket_handle_t target_fd =
        (target && target->ipc_client_fd != IPC_INVALID_SOCKET) ? target->ipc_client_fd : IPC_INVALID_SOCKET;
    if (target_fd == IPC_INVALID_SOCKET && msg->target_window_id >= 0 && msg->target_window_id < g_remote_window_fds_capacity)
        target_fd = g_remote_window_fds[msg->target_window_id];
    pthread_mutex_unlock(&g_wm.mutex);

    if (target_fd != IPC_INVALID_SOCKET)
    {
        ipc_send(target_fd, msg);
    }
}

static void *ipc_conn_handler(void *arg)
{
    ipc_conn_ctx_t *ctx = (ipc_conn_ctx_t *)arg;
    ipc_message_t msg;

    while (g_wm.ipc_server_running)
    {
        if (ipc_recv(ctx->client_fd, &msg) < 0)
            break;

        /* 第一条消息用于注册远端窗口 ID */
        if (ctx->remote_window_id < 0 && msg.source_window_id > 0)
        {
            ctx->remote_window_id = msg.source_window_id;
            /* set_remote_window_fd() 持 g_wm.mutex 完成 ensure+写入；
             * 此前这里是无锁写共享 fd 表，与主线程持锁读构成数据竞争，
             * 偶发导致主进程永远读不到该窗口的 fd（事件推送全部失败）。 */
            set_remote_window_fd(msg.source_window_id, ctx->client_fd);
            pthread_mutex_lock(&g_wm.mutex);
            webview_window_t *w = find_window(msg.source_window_id);
            if (w)
            {
                w->ipc_client_fd = ctx->client_fd;
                w->ipc_state = IPC_CONN_CONNECTED;
            }
            pthread_mutex_unlock(&g_wm.mutex);
        }

        /* 通知应用层 */
        fire_ipc_message(&msg);

        /* 若是请求/数据，尝试路由到目标窗口 */
        if (msg.message_type == IPC_MSG_REQUEST ||
            msg.message_type == IPC_MSG_DATA)
        {
            route_message(&msg);
        }

        /* 若是响应，唤醒等待方 */
        if (msg.message_type == IPC_MSG_RESPONSE)
        {
            pthread_mutex_lock(&g_wm.response_mutex);
            if (g_wm.pending_response &&
                g_wm.pending_msg_id == msg.message_id)
            {
                /* 深拷贝给等待方 */
                *g_wm.pending_response = msg;
                msg.data = NULL; /* 转移所有权，不在此处释放 */
                pthread_cond_signal(&g_wm.response_cond);
            }
            pthread_mutex_unlock(&g_wm.response_mutex);
        }

        ipc_message_free(&msg);
    }

    /* 连接断开：清理映射 */
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(ctx->remote_window_id);
    if (w)
    {
        w->ipc_client_fd = IPC_INVALID_SOCKET;
        w->ipc_state = IPC_CONN_DISCONNECTED;
    }
    pthread_mutex_unlock(&g_wm.mutex);
    clear_remote_window_fd(ctx->remote_window_id);

    socket_close(ctx->client_fd);
    free(ctx);
    return NULL;
}

static void *ipc_server_thread(void *arg)
{
    (void)arg;
    while (g_wm.ipc_server_running)
    {
        fd_set rfds;
        struct timeval tv = {0, 100000}; /* 100ms 超时 */
        FD_ZERO(&rfds);
        FD_SET(g_wm.ipc_socket, &rfds);

        int ret = select(g_wm.ipc_socket + 1, &rfds, NULL, NULL, &tv);
        if (ret < 0)
        {
            if (socket_interrupted(socket_last_error()))
                continue;
            perror("[IPC] select");
            break;
        }
        if (ret == 0)
            continue;

        socket_handle_t client_fd = accept(g_wm.ipc_socket, NULL, NULL);
        if (client_fd == IPC_INVALID_SOCKET)
        {
            int err = socket_last_error();
            if (socket_interrupted(err) || socket_would_block(err))
                continue;
            perror("[IPC] accept");
            continue;
        }
        /* 客户端 fd 保持阻塞模式，由专属线程驱动 */

        ipc_conn_ctx_t *ctx = (ipc_conn_ctx_t *)calloc(1, sizeof(ipc_conn_ctx_t));
        ctx->client_fd = client_fd;
        ctx->remote_window_id = -1;
        pthread_create(&ctx->thread, NULL, ipc_conn_handler, ctx);
        pthread_detach(ctx->thread);
    }
    return NULL;
}

/* ════════════════════════════════════════════════════════════════
   IPC 客户端监听线程（子进程）
   ════════════════════════════════════════════════════════════════ */

static void *ipc_client_listener(void *arg)
{
    (void)arg;
    ipc_message_t msg;

    while (g_ipc_client.connected)
    {
        if (ipc_recv(g_ipc_client.socket_fd, &msg) < 0)
        {
            g_ipc_client.connected = 0;
            g_ipc_client.state = IPC_CONN_DISCONNECTED;
            break;
        }

        fire_ipc_message(&msg);

        /* 响应：唤醒等待方 */
        if (msg.message_type == IPC_MSG_RESPONSE)
        {
            pthread_mutex_lock(&g_wm.response_mutex);
            if (g_wm.pending_response &&
                g_wm.pending_msg_id == msg.message_id)
            {
                *g_wm.pending_response = msg;
                msg.data = NULL;
                pthread_cond_signal(&g_wm.response_cond);
            }
            pthread_mutex_unlock(&g_wm.response_mutex);
        }

        ipc_message_free(&msg);
    }
    return NULL;
}

/* ════════════════════════════════════════════════════════════════
   IPC socket 工厂
   ════════════════════════════════════════════════════════════════ */

static socket_handle_t create_ipc_server_socket(void)
{
    if (winsock_init() != 0)
    {
        return IPC_INVALID_SOCKET;
    }
#ifdef _WIN32
    socket_handle_t sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (sock == IPC_INVALID_SOCKET)
    {
        perror("[IPC] socket");
        return IPC_INVALID_SOCKET;
    }

    set_nonblocking(sock);

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    addr.sin_port = htons(0);

    if (bind(sock, (struct sockaddr *)&addr, sizeof(addr)) != 0)
    {
        perror("[IPC] bind");
        socket_close(sock);
        return IPC_INVALID_SOCKET;
    }

    int addr_len = (int)sizeof(addr);
    if (getsockname(sock, (struct sockaddr *)&addr, &addr_len) != 0)
    {
        perror("[IPC] getsockname");
        socket_close(sock);
        return IPC_INVALID_SOCKET;
    }

    if (listen(sock, IPC_LISTEN_BACKLOG) != 0)
    {
        perror("[IPC] listen");
        socket_close(sock);
        return IPC_INVALID_SOCKET;
    }

    _snprintf(g_wm.ipc_socket_path, sizeof(g_wm.ipc_socket_path),
              "%s:%u", IPC_SOCKET_PATH, (unsigned)ntohs(addr.sin_port));
    {
        char port_buf[16];
        _snprintf(port_buf, sizeof(port_buf), "%u", (unsigned)ntohs(addr.sin_port));
        SetEnvironmentVariableA(IPC_ENDPOINT_ENV, port_buf);
    }
#else
    socket_handle_t sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0)
    {
        perror("[IPC] socket");
        return IPC_INVALID_SOCKET;
    }
    set_nonblocking(sock);

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, g_wm.ipc_socket_path, sizeof(addr.sun_path) - 1);
    unlink(g_wm.ipc_socket_path);

    if (bind(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0)
    {
        perror("[IPC] bind");
        socket_close(sock);
        return IPC_INVALID_SOCKET;
    }
    if (listen(sock, IPC_LISTEN_BACKLOG) < 0)
    {
        perror("[IPC] listen");
        socket_close(sock);
        return IPC_INVALID_SOCKET;
    }
#endif
    g_wm.ipc_socket = sock;
    return sock;
}

static socket_handle_t connect_to_ipc_server(void)
{
    /* 子进程启动时主进程可能还未就绪，最多重试 10 次 */
    for (int attempt = 0; attempt < 10; attempt++)
    {
#ifdef _WIN32
        if (winsock_init() != 0)
            return IPC_INVALID_SOCKET;
        socket_handle_t sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        if (sock == IPC_INVALID_SOCKET)
        {
            perror("[IPC] socket");
            return IPC_INVALID_SOCKET;
        }

        const char *port_str = getenv(IPC_ENDPOINT_ENV);
        if (!port_str || !port_str[0])
        {
            socket_close(sock);
            fprintf(stderr, "[IPC] missing %s\n", IPC_ENDPOINT_ENV);
            return IPC_INVALID_SOCKET;
        }

        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        addr.sin_port = htons((unsigned short)atoi(port_str));
#else
        socket_handle_t sock = socket(AF_UNIX, SOCK_STREAM, 0);
        if (sock < 0)
        {
            perror("[IPC] socket");
            return IPC_INVALID_SOCKET;
        }

        struct sockaddr_un addr;
        memset(&addr, 0, sizeof(addr));
        addr.sun_family = AF_UNIX;
        strncpy(addr.sun_path, g_wm.ipc_socket_path, sizeof(addr.sun_path) - 1);
#endif

        if (connect(sock, (struct sockaddr *)&addr, sizeof(addr)) == 0)
        {
            return sock; /* 成功 */
        }
        socket_close(sock);
        struct timespec ts = {0, 50000000}; /* 50ms */
        nanosleep(&ts, NULL);
    }
    fprintf(stderr, "[IPC] connect failed after retries\n");
    return IPC_INVALID_SOCKET;
}

/* ════════════════════════════════════════════════════════════════
   MoonBit FFI 导出 —— 窗口管理器生命周期
   ════════════════════════════════════════════════════════════════ */

/**
 * 初始化窗口管理器。
 * is_main_process = 1 → 启动 IPC 服务器；= 0 → 子进程模式（跳过服务器）。
 * 返回 0 成功，-1 失败。
 */
MOONBIT_FFI_EXPORT int moonbit_wm_init(int is_main_process)
{
    if (g_wm.initialized)
        return 0;

    g_wm.process_type = is_main_process ? PROCESS_TYPE_MAIN : PROCESS_TYPE_CHILD;
    g_wm.main_process_id = (pid_t)moonbit_wm_get_process_id();

    if (is_main_process)
    {
        if (create_ipc_server_socket() == IPC_INVALID_SOCKET)
            return -1;
        g_wm.ipc_server_running = 1;
        pthread_create(&g_wm.ipc_thread, NULL, ipc_server_thread, NULL);
    }

    g_wm.initialized = 1;
    g_wm.on_ipc_message = ipc_recv_callback;
    return 0;
}

/**
 * 销毁所有窗口并释放全局资源。
 */
MOONBIT_FFI_EXPORT void moonbit_wm_cleanup(void)
{
    if (!g_wm.initialized)
        return;

    /* 关闭所有窗口 */
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *cur = g_wm.head;
    while (cur)
    {
        webview_window_t *nxt = cur->next;
        if (cur->handle)
        {
            webview_destroy(cur->handle);
            cur->handle = NULL;
        }
        free(cur);
        cur = nxt;
    }
    g_wm.head = g_wm.tail = NULL;
    g_wm.window_count = 0;
    pthread_mutex_unlock(&g_wm.mutex);

    /* 关闭 IPC 服务器 */
    if (g_wm.ipc_server_running)
    {
        g_wm.ipc_server_running = 0;
        pthread_join(g_wm.ipc_thread, NULL);
        socket_close(g_wm.ipc_socket);
#ifndef _WIN32
        unlink(g_wm.ipc_socket_path);
#else
        SetEnvironmentVariableA(IPC_ENDPOINT_ENV, NULL);
#endif
        g_wm.ipc_socket = IPC_INVALID_SOCKET;
    }

    /* 关闭子进程 IPC 客户端 */
    if (g_ipc_client.connected)
    {
        g_ipc_client.connected = 0;
        pthread_join(g_ipc_client.listener_thread, NULL);
        socket_close(g_ipc_client.socket_fd);
        g_ipc_client.socket_fd = IPC_INVALID_SOCKET;
        g_ipc_client.state = IPC_CONN_DISCONNECTED;
    }

    g_wm.initialized = 0;
}

/* ════════════════════════════════════════════════════════════════
   MoonBit FFI 导出 —— 窗口创建 / 销毁 / 运行
   ════════════════════════════════════════════════════════════════ */

/**
 * 创建并注册一个新窗口。
 * 返回 window_id（>0），失败返回 -1。
 */
MOONBIT_FFI_EXPORT int moonbit_wm_create_window(
    const char *title,
    const char *url,
    int width, int height,
    int x, int y,
    int hints,
    int debug,
    int parent_window_id)
{
    if (!g_wm.initialized)
        moonbit_wm_init(1);

    webview_window_t *w = (webview_window_t *)calloc(1, sizeof(webview_window_t));
    if (!w)
        return -1;

    w->window_id = alloc_window_id();
    w->process_id = (pid_t)moonbit_wm_get_process_id();
    w->process_type = g_wm.process_type;
    w->state = WINDOW_STATE_CREATED;
    w->parent_window_id = parent_window_id;
    w->is_child_process = (g_wm.process_type == PROCESS_TYPE_CHILD) ? 1 : 0;
    w->visible = 1;
    w->fullscreen = 0;
    w->ipc_client_fd = IPC_INVALID_SOCKET;
    w->ipc_state = IPC_CONN_DISCONNECTED;
    w->width = width > 0 ? width : 800;
    w->height = height > 0 ? height : 600;
    w->x = x;
    w->y = y;
    w->hints = hints;
    w->debug_mode = debug;
    strncpy(w->title, title ? title : "MoonBit WebView", sizeof(w->title) - 1);
    strncpy(w->url, url ? url : "", sizeof(w->url) - 1);

    /* 创建底层 webview 实例 */
    w->handle = webview_create(debug, NULL);
    if (!w->handle)
    {
        free(w);
        return -1;
    }
#ifdef __APPLE__
    if (g_macos_default_menu_enabled)
        moonbit_macos_install_default_menu();
#endif

    webview_set_title(w->handle, w->title);
    webview_set_size(w->handle, w->width, w->height, w->hints);
    if (w->url[0])
        webview_navigate(w->handle, w->url);

    wm_add(w);

    if (g_wm.on_window_created)
        g_wm.on_window_created(w);
    fire_window_event(w, WINDOW_EVT_CREATED, NULL);

    return w->window_id;
}

MOONBIT_FFI_EXPORT int moonbit_wm_menu_supported(void)
{
#ifdef __APPLE__
    return 1;
#else
    return 0;
#endif
}

MOONBIT_FFI_EXPORT int moonbit_wm_get_default_macos_menu(void)
{
#ifdef __APPLE__
    return g_macos_default_menu_enabled;
#else
    return 0;
#endif
}

MOONBIT_FFI_EXPORT int moonbit_wm_set_default_macos_menu(int enabled)
{
#ifdef __APPLE__
    g_macos_default_menu_enabled = enabled ? 1 : 0;
    if (g_macos_default_menu_enabled)
        moonbit_macos_install_default_menu();
    else
        moonbit_macos_clear_main_menu();
    return 0;
#else
    (void)enabled;
    return -1;
#endif
}

/**
 * 销毁指定窗口并从管理器移除。
 * 返回 0 成功，-1 未找到。
 */
MOONBIT_FFI_EXPORT int moonbit_wm_destroy_window(int window_id)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w)
        return -1;

    w->state = WINDOW_STATE_CLOSING;
    fire_window_event(w, WINDOW_EVT_CLOSING, NULL);

    if (w->handle)
    {
        webview_destroy(w->handle);
        w->handle = NULL;
    }
    if (w->ipc_client_fd != IPC_INVALID_SOCKET)
    {
        socket_close(w->ipc_client_fd);
        w->ipc_client_fd = IPC_INVALID_SOCKET;
    }

    w->state = WINDOW_STATE_CLOSED;
    fire_window_event(w, WINDOW_EVT_CLOSED, NULL);

    wm_remove(w);
    if (g_wm.on_window_destroyed)
        g_wm.on_window_destroyed(window_id);
    free(w);
    return 0;
}

/**
 * 阻塞式运行窗口事件循环（直到 webview_terminate 被调用）。
 */
MOONBIT_FFI_EXPORT int moonbit_wm_run_window(int window_id)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;

    w->state = WINDOW_STATE_RUNNING;
    webview_run(w->handle);
    return 0;
}

typedef struct
{
    int window_id;
} run_window_async_ctx_t;

static void *run_window_async_main(void *arg)
{
    run_window_async_ctx_t *ctx = (run_window_async_ctx_t *)arg;
    int window_id = ctx->window_id;
    free(ctx);

    moonbit_wm_run_window(window_id);
    moonbit_wm_destroy_window(window_id);
    return NULL;
}

MOONBIT_FFI_EXPORT int moonbit_wm_run_window_async(int window_id)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;

    run_window_async_ctx_t *ctx =
        (run_window_async_ctx_t *)malloc(sizeof(run_window_async_ctx_t));
    if (!ctx)
        return -1;
    ctx->window_id = window_id;

    pthread_t thread;
    if (pthread_create(&thread, NULL, run_window_async_main, ctx) != 0)
    {
        free(ctx);
        return -1;
    }
    pthread_detach(thread);
    return 0;
}

/**
 * 请求窗口退出其事件循环。
 */
MOONBIT_FFI_EXPORT int moonbit_wm_terminate_window(int window_id)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;

    webview_terminate(w->handle);
    return 0;
}

/* ════════════════════════════════════════════════════════════════
   MoonBit FFI 导出 —— 窗口属性
   ════════════════════════════════════════════════════════════════ */

MOONBIT_FFI_EXPORT int moonbit_wm_set_title(int window_id, const char *title)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;

    strncpy(w->title, title, sizeof(w->title) - 1);
    webview_set_title(w->handle, title);
    return 0;
}

MOONBIT_FFI_EXPORT int moonbit_wm_set_size(int window_id, int width, int height, int hints)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;

    w->width = width;
    w->height = height;
    w->hints = hints;
    webview_set_size(w->handle, width, height, hints);

    int size_data[2] = {width, height};
    fire_window_event(w, WINDOW_EVT_RESIZED, size_data);
    return 0;
}

static void *moonbit_window_native_handle(webview_window_t *w)
{
    if (!w || !w->handle)
        return NULL;
    int64_t native = webview_get_native_handle(w->handle, 0);
    if (native == 0)
        native = webview_get_window(w->handle);
    return (void *)(intptr_t)native;
}

#ifdef __APPLE__
typedef void *mb_id_t;
typedef void *mb_sel_t;
typedef struct
{
    double x;
    double y;
} mb_point_t;
typedef struct
{
    double x;
    double y;
    double width;
    double height;
} mb_rect_t;
typedef mb_sel_t (*mb_sel_register_name_t)(const char *);
typedef mb_id_t (*mb_objc_get_class_t)(const char *);
typedef unsigned long (*mb_objc_msgsend_u64_t)(mb_id_t, mb_sel_t);
typedef mb_id_t (*mb_objc_msgsend_id_ret_t)(mb_id_t, mb_sel_t);
typedef mb_rect_t (*mb_objc_msgsend_rect_ret_t)(mb_id_t, mb_sel_t);
typedef mb_id_t (*mb_objc_msgsend_cstr_arg_ret_t)(mb_id_t, mb_sel_t, const char *);
typedef mb_id_t (*mb_objc_msgsend_int_arg_ret_t)(mb_id_t, mb_sel_t, int);
typedef mb_id_t (*mb_objc_msgsend_u64_arg_ret_t)(mb_id_t, mb_sel_t, unsigned long);
typedef int (*mb_objc_msgsend_id_arg_int_ret_t)(mb_id_t, mb_sel_t, mb_id_t);
typedef void (*mb_objc_msgsend_u64_arg_t)(mb_id_t, mb_sel_t, unsigned long);
typedef void (*mb_objc_msgsend_long_arg_t)(mb_id_t, mb_sel_t, long);
typedef void (*mb_objc_msgsend_int_arg_t)(mb_id_t, mb_sel_t, int);
typedef void (*mb_objc_msgsend_id_arg_t)(mb_id_t, mb_sel_t, mb_id_t);
typedef void (*mb_objc_msgsend_id_id_arg_t)(mb_id_t, mb_sel_t, mb_id_t, mb_id_t);
typedef void (*mb_objc_msgsend_point_arg_t)(mb_id_t, mb_sel_t, mb_point_t);
typedef mb_id_t (*mb_objc_msgsend_id_sel_id_arg_ret_t)(mb_id_t, mb_sel_t, mb_id_t, mb_sel_t, mb_id_t);
typedef int (*mb_objc_msgsend_sel_arg_t)(mb_id_t, mb_sel_t, mb_sel_t);
typedef int (*mb_objc_msgsend_int_ret_t)(mb_id_t, mb_sel_t);

static void *moonbit_objc_msgsend_symbol(void)
{
    static void *sym = NULL;
    static int loaded = 0;
    if (!loaded)
    {
        void *lib = dlopen("/usr/lib/libobjc.A.dylib", RTLD_LAZY);
        if (!lib)
            lib = dlopen("/usr/lib/libobjc.dylib", RTLD_LAZY);
        sym = lib ? dlsym(lib, "objc_msgSend") : NULL;
        loaded = 1;
    }
    return sym;
}

static mb_sel_t moonbit_sel_register_name(const char *name)
{
    static mb_sel_register_name_t fn = NULL;
    static int loaded = 0;
    if (!loaded)
    {
        void *lib = dlopen("/usr/lib/libobjc.A.dylib", RTLD_LAZY);
        if (!lib)
            lib = dlopen("/usr/lib/libobjc.dylib", RTLD_LAZY);
        fn = lib ? (mb_sel_register_name_t)dlsym(lib, "sel_registerName") : NULL;
        loaded = 1;
    }
    return fn ? fn(name) : NULL;
}

static mb_id_t moonbit_objc_get_class(const char *name)
{
    static mb_objc_get_class_t fn = NULL;
    static int loaded = 0;
    if (!loaded)
    {
        void *lib = dlopen("/usr/lib/libobjc.A.dylib", RTLD_LAZY);
        if (!lib)
            lib = dlopen("/usr/lib/libobjc.dylib", RTLD_LAZY);
        fn = lib ? (mb_objc_get_class_t)dlsym(lib, "objc_getClass") : NULL;
        loaded = 1;
    }
    return fn ? fn(name) : NULL;
}

static mb_id_t moonbit_find_wk_webview(mb_id_t view, void *msgsend)
{
    if (!view || !msgsend)
        return NULL;
    mb_id_t wk_cls = moonbit_objc_get_class("WKWebView");
    mb_sel_t sel_is_kind = moonbit_sel_register_name("isKindOfClass:");
    if (wk_cls && sel_is_kind)
    {
        if (((mb_objc_msgsend_id_arg_int_ret_t)msgsend)(view, sel_is_kind, wk_cls))
            return view;
    }
    mb_sel_t sel_subviews = moonbit_sel_register_name("subviews");
    mb_sel_t sel_count = moonbit_sel_register_name("count");
    mb_sel_t sel_object_at_index = moonbit_sel_register_name("objectAtIndex:");
    if (!sel_subviews || !sel_count || !sel_object_at_index)
        return NULL;
    mb_id_t subviews = ((mb_objc_msgsend_id_ret_t)msgsend)(view, sel_subviews);
    if (!subviews)
        return NULL;
    unsigned long count = ((mb_objc_msgsend_u64_t)msgsend)(subviews, sel_count);
    for (unsigned long i = 0; i < count; i++)
    {
        mb_id_t child = ((mb_objc_msgsend_u64_arg_ret_t)msgsend)(subviews, sel_object_at_index, i);
        mb_id_t wk = moonbit_find_wk_webview(child, msgsend);
        if (wk)
            return wk;
    }
    return NULL;
}

static mb_id_t moonbit_nsstring_from_utf8(const char *value, void *msgsend)
{
    if (!value || !msgsend)
        return NULL;
    mb_id_t ns_string = moonbit_objc_get_class("NSString");
    mb_sel_t sel_string_with_utf8 = moonbit_sel_register_name("stringWithUTF8String:");
    if (!ns_string || !sel_string_with_utf8)
        return NULL;
    return ((mb_objc_msgsend_cstr_arg_ret_t)msgsend)(ns_string, sel_string_with_utf8, value);
}

static mb_id_t moonbit_menu_add_item(
    mb_id_t menu,
    const char *title,
    const char *action_name,
    const char *key_equivalent,
    unsigned long key_modifiers,
    void *msgsend)
{
    if (!menu || !msgsend)
        return NULL;
    mb_sel_t sel_add_item = moonbit_sel_register_name("addItemWithTitle:action:keyEquivalent:");
    mb_sel_t sel_set_key_mask = moonbit_sel_register_name("setKeyEquivalentModifierMask:");
    if (!sel_add_item || !sel_set_key_mask)
        return NULL;

    mb_id_t ns_title = moonbit_nsstring_from_utf8(title ? title : "", msgsend);
    mb_id_t ns_key = moonbit_nsstring_from_utf8(key_equivalent ? key_equivalent : "", msgsend);
    mb_sel_t action = moonbit_sel_register_name(action_name ? action_name : "");
    if (!ns_title || !ns_key)
        return NULL;

    mb_id_t item = ((mb_objc_msgsend_id_sel_id_arg_ret_t)msgsend)(
        menu,
        sel_add_item,
        ns_title,
        action,
        ns_key);
    if (item && key_modifiers != 0)
        ((mb_objc_msgsend_u64_arg_t)msgsend)(item, sel_set_key_mask, key_modifiers);
    return item;
}

static mb_id_t moonbit_macos_process_name(void *msgsend)
{
    if (!msgsend)
        return moonbit_nsstring_from_utf8("App", msgsend);
    mb_id_t ns_process_info = moonbit_objc_get_class("NSProcessInfo");
    mb_sel_t sel_process_info = moonbit_sel_register_name("processInfo");
    mb_sel_t sel_process_name = moonbit_sel_register_name("processName");
    if (!ns_process_info || !sel_process_info || !sel_process_name)
        return moonbit_nsstring_from_utf8("App", msgsend);
    mb_id_t process_info = ((mb_objc_msgsend_id_ret_t)msgsend)(ns_process_info, sel_process_info);
    if (!process_info)
        return moonbit_nsstring_from_utf8("App", msgsend);
    mb_id_t process_name = ((mb_objc_msgsend_id_ret_t)msgsend)(process_info, sel_process_name);
    return process_name ? process_name : moonbit_nsstring_from_utf8("App", msgsend);
}

static mb_id_t moonbit_macos_new_menu_item(mb_id_t ns_menu_item_cls, mb_id_t title, void *msgsend)
{
    if (!ns_menu_item_cls || !title || !msgsend)
        return NULL;
    mb_sel_t sel_alloc = moonbit_sel_register_name("alloc");
    mb_sel_t sel_init_with_title = moonbit_sel_register_name("initWithTitle:action:keyEquivalent:");
    mb_id_t empty_key = moonbit_nsstring_from_utf8("", msgsend);
    if (!sel_alloc || !sel_init_with_title || !empty_key)
        return NULL;
    mb_id_t item_alloc = ((mb_objc_msgsend_id_ret_t)msgsend)(ns_menu_item_cls, sel_alloc);
    if (!item_alloc)
        return NULL;
    return ((mb_objc_msgsend_id_sel_id_arg_ret_t)msgsend)(
        item_alloc,
        sel_init_with_title,
        title,
        NULL,
        empty_key);
}

static void moonbit_macos_install_default_menu(void)
{
    static int installed = 0;
    if (installed)
        return;

    void *msgsend = moonbit_objc_msgsend_symbol();
    mb_id_t ns_app_cls = moonbit_objc_get_class("NSApplication");
    mb_id_t ns_menu_cls = moonbit_objc_get_class("NSMenu");
    mb_id_t ns_menu_item_cls = moonbit_objc_get_class("NSMenuItem");
    if (!msgsend || !ns_app_cls || !ns_menu_cls || !ns_menu_item_cls)
        return;

    mb_sel_t sel_shared = moonbit_sel_register_name("sharedApplication");
    mb_sel_t sel_main_menu = moonbit_sel_register_name("mainMenu");
    mb_sel_t sel_set_main_menu = moonbit_sel_register_name("setMainMenu:");
    mb_sel_t sel_alloc = moonbit_sel_register_name("alloc");
    mb_sel_t sel_init = moonbit_sel_register_name("init");
    mb_sel_t sel_set_submenu = moonbit_sel_register_name("setSubmenu:forItem:");
    mb_sel_t sel_add_item_simple = moonbit_sel_register_name("addItem:");
    if (!sel_shared || !sel_main_menu || !sel_set_main_menu || !sel_alloc || !sel_init || !sel_set_submenu || !sel_add_item_simple)
        return;

    mb_id_t app = ((mb_objc_msgsend_id_ret_t)msgsend)(ns_app_cls, sel_shared);
    if (!app)
        return;

    mb_id_t existing_main = ((mb_objc_msgsend_id_ret_t)msgsend)(app, sel_main_menu);
    if (existing_main)
    {
        installed = 1;
        return;
    }

    const unsigned long NSEventModifierFlagShift = 1UL << 17;
    const unsigned long NSEventModifierFlagCommand = 1UL << 20;

    mb_id_t main_menu = ((mb_objc_msgsend_id_ret_t)msgsend)(((mb_objc_msgsend_id_ret_t)msgsend)(ns_menu_cls, sel_alloc), sel_init);
    mb_id_t app_title = moonbit_macos_process_name(msgsend);
    mb_id_t edit_title = moonbit_nsstring_from_utf8("Edit", msgsend);
    mb_id_t app_menu_item = moonbit_macos_new_menu_item(ns_menu_item_cls, app_title, msgsend);
    mb_id_t edit_menu_item = moonbit_macos_new_menu_item(ns_menu_item_cls, edit_title, msgsend);
    mb_id_t app_menu = ((mb_objc_msgsend_id_ret_t)msgsend)(((mb_objc_msgsend_id_ret_t)msgsend)(ns_menu_cls, sel_alloc), sel_init);
    mb_id_t edit_menu = ((mb_objc_msgsend_id_ret_t)msgsend)(((mb_objc_msgsend_id_ret_t)msgsend)(ns_menu_cls, sel_alloc), sel_init);
    if (!main_menu || !app_menu_item || !edit_menu_item || !app_menu || !edit_menu)
        return;

    ((mb_objc_msgsend_id_arg_t)msgsend)(main_menu, sel_add_item_simple, app_menu_item);
    ((mb_objc_msgsend_id_arg_t)msgsend)(main_menu, sel_add_item_simple, edit_menu_item);

    moonbit_menu_add_item(app_menu, "Quit", "terminate:", "q", NSEventModifierFlagCommand, msgsend);
    moonbit_menu_add_item(edit_menu, "Undo", "undo:", "z", NSEventModifierFlagCommand, msgsend);
    moonbit_menu_add_item(edit_menu, "Redo", "redo:", "Z", NSEventModifierFlagCommand | NSEventModifierFlagShift, msgsend);
    moonbit_menu_add_item(edit_menu, "Cut", "cut:", "x", NSEventModifierFlagCommand, msgsend);
    moonbit_menu_add_item(edit_menu, "Copy", "copy:", "c", NSEventModifierFlagCommand, msgsend);
    moonbit_menu_add_item(edit_menu, "Paste", "paste:", "v", NSEventModifierFlagCommand, msgsend);
    moonbit_menu_add_item(edit_menu, "Select All", "selectAll:", "a", NSEventModifierFlagCommand, msgsend);

    ((mb_objc_msgsend_id_id_arg_t)msgsend)(main_menu, sel_set_submenu, app_menu, app_menu_item);
    ((mb_objc_msgsend_id_id_arg_t)msgsend)(main_menu, sel_set_submenu, edit_menu, edit_menu_item);
    ((mb_objc_msgsend_id_arg_t)msgsend)(app, sel_set_main_menu, main_menu);
    installed = 1;
}

static void moonbit_macos_clear_main_menu(void)
{
    void *msgsend = moonbit_objc_msgsend_symbol();
    mb_id_t ns_app_cls = moonbit_objc_get_class("NSApplication");
    mb_sel_t sel_shared = moonbit_sel_register_name("sharedApplication");
    mb_sel_t sel_set_main_menu = moonbit_sel_register_name("setMainMenu:");
    if (!msgsend || !ns_app_cls || !sel_shared || !sel_set_main_menu)
        return;
    mb_id_t app = ((mb_objc_msgsend_id_ret_t)msgsend)(ns_app_cls, sel_shared);
    if (!app)
        return;
    ((mb_objc_msgsend_id_arg_t)msgsend)(app, sel_set_main_menu, NULL);
}

/*
 * 把当前进程激活为前台 app（参考 tao/winit 的 util::set_focus 与
 * vendored webview.h on_application_did_finish_launching）。
 *
 * "setActivationPolicy:"（NSApplicationActivationPolicyRegular = 0）必须先于
 * activate，否则非 bundle 进程（如 moon run 直接启动的辅助进程、我们的多窗口
 * 子进程）激活请求会被忽略。
 *
 * macOS 14 起 activateIgnoringOtherApps: 被废弃且在新系统上可能被静默忽略；
 * 优先使用 activateWithOptions:（NSApplicationActivateAllWindows(1) |
 * NSApplicationActivateIgnoringOtherApps(2)），旧系统回退到
 * activateIgnoringOtherApps:。
 */
static void moonbit_macos_activate_app(void)
{
    void *msgsend = moonbit_objc_msgsend_symbol();
    if (!msgsend)
        return;
    mb_id_t app = ((mb_objc_msgsend_id_ret_t)msgsend)(
        moonbit_objc_get_class("NSApplication"),
        moonbit_sel_register_name("sharedApplication"));
    if (!app)
        return;

    mb_sel_t sel_policy = moonbit_sel_register_name("setActivationPolicy:");
    if (sel_policy)
        ((mb_objc_msgsend_long_arg_t)msgsend)(app, sel_policy, 0L);

    mb_sel_t sel_activate_opts = moonbit_sel_register_name("activateWithOptions:");
    mb_sel_t sel_responds = moonbit_sel_register_name("respondsToSelector:");
    if (sel_activate_opts && sel_responds &&
        ((mb_objc_msgsend_sel_arg_t)msgsend)(app, sel_responds, sel_activate_opts))
    {
        ((mb_objc_msgsend_u64_arg_t)msgsend)(app, sel_activate_opts, 1UL | 2UL);
    }
    else
    {
        mb_sel_t sel_activate_legacy = moonbit_sel_register_name("activateIgnoringOtherApps:");
        if (sel_activate_legacy)
            ((mb_objc_msgsend_int_arg_t)msgsend)(app, sel_activate_legacy, 1);
    }
}
#endif

MOONBIT_FFI_EXPORT int moonbit_wm_set_window_customization(
    int window_id,
    int frameless,
    int resizable,
    int closeable,
    int always_on_top,
    int transparent,
    int title_bar_style,
    int title_bar_overlay)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;

#ifdef _WIN32
    HWND hwnd = (HWND)moonbit_window_native_handle(w);
    if (!hwnd)
        return -1;
    int hidden_title_bar = title_bar_style == 1;
    LONG style = GetWindowLong(hwnd, GWL_STYLE);
    if (frameless && !title_bar_overlay && !hidden_title_bar)
        style &= ~(WS_CAPTION | WS_THICKFRAME);
    else
        style |= WS_CAPTION;
    if (closeable)
        style |= WS_SYSMENU;
    else
        style &= ~WS_SYSMENU;
    if (resizable)
        style |= (WS_THICKFRAME | WS_MAXIMIZEBOX);
    else
        style &= ~(WS_THICKFRAME | WS_MAXIMIZEBOX);
    SetWindowLong(hwnd, GWL_STYLE, style);
    LONG exstyle = GetWindowLong(hwnd, GWL_EXSTYLE);
    if (transparent)
        exstyle |= WS_EX_LAYERED;
    else
        exstyle &= ~WS_EX_LAYERED;
    SetWindowLong(hwnd, GWL_EXSTYLE, exstyle);
    if (transparent)
        SetLayeredWindowAttributes(hwnd, 0, 235, LWA_ALPHA);
    else
        SetLayeredWindowAttributes(hwnd, 0, 255, LWA_ALPHA);
    SetWindowPos(
        hwnd,
        always_on_top ? HWND_TOPMOST : HWND_NOTOPMOST,
        0,
        0,
        0,
        0,
        SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED);
    return 0;
#elif defined(__APPLE__)
    void *ns_window = moonbit_window_native_handle(w);
    void *msgsend = moonbit_objc_msgsend_symbol();
    if (!ns_window || !msgsend)
        return -1;
    int hidden_title_bar = title_bar_style == 1;
    mb_sel_t sel_style_mask = moonbit_sel_register_name("styleMask");
    mb_sel_t sel_set_style_mask = moonbit_sel_register_name("setStyleMask:");
    if (!sel_style_mask || !sel_set_style_mask)
        return -1;
    unsigned long style = ((mb_objc_msgsend_u64_t)msgsend)((mb_id_t)ns_window, sel_style_mask);
    const unsigned long NSWindowStyleMaskTitled = 1UL << 0;
    const unsigned long NSWindowStyleMaskClosable = 1UL << 1;
    const unsigned long NSWindowStyleMaskMiniaturizable = 1UL << 2;
    const unsigned long NSWindowStyleMaskResizable = 1UL << 3;
    const unsigned long NSWindowStyleMaskFullSizeContentView = 1UL << 15;
    if (hidden_title_bar)
    {
        style |= (NSWindowStyleMaskTitled | NSWindowStyleMaskMiniaturizable);
        style |= NSWindowStyleMaskFullSizeContentView;
    }
    else if (frameless)
    {
        style &= ~(NSWindowStyleMaskTitled | NSWindowStyleMaskMiniaturizable);
        style |= NSWindowStyleMaskFullSizeContentView;
    }
    else
    {
        style |= (NSWindowStyleMaskTitled | NSWindowStyleMaskMiniaturizable);
        style &= ~NSWindowStyleMaskFullSizeContentView;
    }
    if (closeable)
        style |= NSWindowStyleMaskClosable;
    else
        style &= ~NSWindowStyleMaskClosable;
    if (resizable)
        style |= NSWindowStyleMaskResizable;
    else
        style &= ~NSWindowStyleMaskResizable;
    ((mb_objc_msgsend_u64_arg_t)msgsend)((mb_id_t)ns_window, sel_set_style_mask, style);
    if (frameless || hidden_title_bar || title_bar_overlay)
    {
        ((mb_objc_msgsend_long_arg_t)msgsend)((mb_id_t)ns_window, moonbit_sel_register_name("setTitleVisibility:"), 1L);
        ((mb_objc_msgsend_int_arg_t)msgsend)((mb_id_t)ns_window, moonbit_sel_register_name("setTitlebarAppearsTransparent:"), 1);
        ((mb_objc_msgsend_int_arg_t)msgsend)((mb_id_t)ns_window, moonbit_sel_register_name("setMovableByWindowBackground:"), 1);
    }
    ((mb_objc_msgsend_long_arg_t)msgsend)(
        (mb_id_t)ns_window,
        moonbit_sel_register_name("setLevel:"),
        always_on_top ? 3L : 0L);
    mb_sel_t sel_set_opaque = moonbit_sel_register_name("setOpaque:");
    if (sel_set_opaque)
        ((mb_objc_msgsend_int_arg_t)msgsend)((mb_id_t)ns_window, sel_set_opaque, transparent ? 0 : 1);
    if (transparent)
    {
        mb_id_t ns_color = moonbit_objc_get_class("NSColor");
        mb_sel_t sel_clear_color = moonbit_sel_register_name("clearColor");
        mb_sel_t sel_set_background = moonbit_sel_register_name("setBackgroundColor:");
        if (ns_color && sel_clear_color && sel_set_background)
        {
            mb_id_t clear = ((mb_objc_msgsend_id_ret_t)msgsend)(ns_color, sel_clear_color);
            ((mb_objc_msgsend_id_arg_t)msgsend)((mb_id_t)ns_window, sel_set_background, clear);
        }
        mb_sel_t sel_content_view = moonbit_sel_register_name("contentView");
        mb_sel_t sel_subviews = moonbit_sel_register_name("subviews");
        mb_sel_t sel_count = moonbit_sel_register_name("count");
        mb_sel_t sel_object_at_index = moonbit_sel_register_name("objectAtIndex:");
        mb_sel_t sel_set_opaque = moonbit_sel_register_name("setOpaque:");
        mb_sel_t sel_set_value_for_key = moonbit_sel_register_name("setValue:forKey:");
        mb_id_t content_view = sel_content_view ? ((mb_objc_msgsend_id_ret_t)msgsend)((mb_id_t)ns_window, sel_content_view) : NULL;
        mb_id_t views = (content_view && sel_subviews) ? ((mb_objc_msgsend_id_ret_t)msgsend)(content_view, sel_subviews) : NULL;
        unsigned long count = (views && sel_count) ? ((mb_objc_msgsend_u64_t)msgsend)(views, sel_count) : 0;
        mb_id_t ns_number = moonbit_objc_get_class("NSNumber");
        mb_id_t ns_string = moonbit_objc_get_class("NSString");
        mb_sel_t sel_number_with_bool = moonbit_sel_register_name("numberWithBool:");
        mb_sel_t sel_string_with_utf8 = moonbit_sel_register_name("stringWithUTF8String:");
        mb_id_t bool_no = (ns_number && sel_number_with_bool) ? ((mb_objc_msgsend_int_arg_ret_t)msgsend)(ns_number, sel_number_with_bool, 0) : NULL;
        mb_id_t key_draws_background =
            (ns_string && sel_string_with_utf8) ? ((mb_objc_msgsend_cstr_arg_ret_t)msgsend)(ns_string, sel_string_with_utf8, "drawsBackground") : NULL;
        for (unsigned long i = 0; i < count; i++)
        {
            mb_id_t view = sel_object_at_index ? ((mb_objc_msgsend_u64_arg_ret_t)msgsend)(views, sel_object_at_index, i) : NULL;
            if (!view)
                continue;
            if (sel_set_opaque)
                ((mb_objc_msgsend_int_arg_t)msgsend)(view, sel_set_opaque, 0);
            if (sel_set_value_for_key && bool_no && key_draws_background)
                ((mb_objc_msgsend_id_id_arg_t)msgsend)(view, sel_set_value_for_key, bool_no, key_draws_background);
        }
    }
    return 0;
#else
    (void)frameless;
    (void)resizable;
    (void)closeable;
    (void)always_on_top;
    (void)transparent;
    (void)title_bar_style;
    (void)title_bar_overlay;
    return 0;
#endif
}

MOONBIT_FFI_EXPORT int moonbit_wm_set_traffic_light_position(int window_id, int x, int y)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;
#ifdef __APPLE__
    void *ns_window = moonbit_window_native_handle(w);
    void *msgsend = moonbit_objc_msgsend_symbol();
    if (!ns_window || !msgsend)
        return -1;
    mb_sel_t sel_standard_button = moonbit_sel_register_name("standardWindowButton:");
    mb_sel_t sel_superview = moonbit_sel_register_name("superview");
    mb_sel_t sel_frame = moonbit_sel_register_name("frame");
    mb_sel_t sel_set_frame_origin = moonbit_sel_register_name("setFrameOrigin:");
    if (!sel_standard_button || !sel_superview || !sel_frame || !sel_set_frame_origin)
        return -1;

    mb_id_t close_btn = ((mb_objc_msgsend_int_arg_ret_t)msgsend)((mb_id_t)ns_window, sel_standard_button, 0);
    mb_id_t mini_btn = ((mb_objc_msgsend_int_arg_ret_t)msgsend)((mb_id_t)ns_window, sel_standard_button, 1);
    mb_id_t zoom_btn = ((mb_objc_msgsend_int_arg_ret_t)msgsend)((mb_id_t)ns_window, sel_standard_button, 2);
    if (!close_btn || !mini_btn || !zoom_btn)
        return -1;

    mb_id_t titlebar = ((mb_objc_msgsend_id_ret_t)msgsend)(close_btn, sel_superview);
    if (!titlebar)
        return -1;

    mb_rect_t titlebar_frame = ((mb_objc_msgsend_rect_ret_t)msgsend)(titlebar, sel_frame);
    mb_rect_t close_frame = ((mb_objc_msgsend_rect_ret_t)msgsend)(close_btn, sel_frame);
    mb_rect_t mini_frame = ((mb_objc_msgsend_rect_ret_t)msgsend)(mini_btn, sel_frame);
    mb_rect_t zoom_frame = ((mb_objc_msgsend_rect_ret_t)msgsend)(zoom_btn, sel_frame);

    double spacing = 6.0;
    double btn_y = titlebar_frame.height - (double)y - close_frame.height;
    if (btn_y < 0)
        btn_y = 0;
    mb_point_t close_origin = {(double)x, btn_y};
    mb_point_t mini_origin = {close_origin.x + close_frame.width + spacing, btn_y};
    mb_point_t zoom_origin = {mini_origin.x + mini_frame.width + spacing, btn_y};

    ((mb_objc_msgsend_point_arg_t)msgsend)(close_btn, sel_set_frame_origin, close_origin);
    ((mb_objc_msgsend_point_arg_t)msgsend)(mini_btn, sel_set_frame_origin, mini_origin);
    ((mb_objc_msgsend_point_arg_t)msgsend)(zoom_btn, sel_set_frame_origin, zoom_origin);
    return 0;
#else
    (void)x;
    (void)y;
    return 0;
#endif
}

MOONBIT_FFI_EXPORT int moonbit_wm_set_position(int window_id, int x, int y)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;
#ifdef _WIN32
    HWND hwnd = (HWND)moonbit_window_native_handle(w);
    if (!hwnd)
        return -1;
    RECT rc;
    GetWindowRect(hwnd, &rc);
    int width = rc.right - rc.left;
    int height = rc.bottom - rc.top;
    if (!MoveWindow(hwnd, x, y, width, height, TRUE))
        return -1;
#elif defined(__APPLE__)
    void *ns_window = moonbit_window_native_handle(w);
    void *msgsend = moonbit_objc_msgsend_symbol();
    if (!ns_window || !msgsend)
        return -1;
    mb_sel_t sel_set_frame_origin = moonbit_sel_register_name("setFrameOrigin:");
    if (!sel_set_frame_origin)
        return -1;
    mb_point_t origin = {(double)x, (double)y};
    ((mb_objc_msgsend_point_arg_t)msgsend)((mb_id_t)ns_window, sel_set_frame_origin, origin);
#else
    (void)x;
    (void)y;
    return -1;
#endif
    w->x = x;
    w->y = y;
    int pos_data[2] = {x, y};
    fire_window_event(w, WINDOW_EVT_MOVED, pos_data);
    return 0;
}

MOONBIT_FFI_EXPORT int moonbit_wm_minimize_window(int window_id)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;
#ifdef _WIN32
    HWND hwnd = (HWND)moonbit_window_native_handle(w);
    if (!hwnd)
        return -1;
    ShowWindow(hwnd, SW_MINIMIZE);
    return 0;
#elif defined(__APPLE__)
    void *ns_window = moonbit_window_native_handle(w);
    void *msgsend = moonbit_objc_msgsend_symbol();
    if (!ns_window || !msgsend)
        return -1;
    ((mb_objc_msgsend_id_arg_t)msgsend)((mb_id_t)ns_window, moonbit_sel_register_name("performMiniaturize:"), (mb_id_t)ns_window);
    return 0;
#else
    return -1;
#endif
}

MOONBIT_FFI_EXPORT int moonbit_wm_maximize_window(int window_id)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;
#ifdef _WIN32
    HWND hwnd = (HWND)moonbit_window_native_handle(w);
    if (!hwnd)
        return -1;
    ShowWindow(hwnd, SW_MAXIMIZE);
    return 0;
#elif defined(__APPLE__)
    void *ns_window = moonbit_window_native_handle(w);
    void *msgsend = moonbit_objc_msgsend_symbol();
    if (!ns_window || !msgsend)
        return -1;
    ((mb_objc_msgsend_id_arg_t)msgsend)((mb_id_t)ns_window, moonbit_sel_register_name("zoom:"), (mb_id_t)ns_window);
    return 0;
#else
    return -1;
#endif
}

MOONBIT_FFI_EXPORT int moonbit_wm_unmaximize_window(int window_id)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;
#ifdef _WIN32
    HWND hwnd = (HWND)moonbit_window_native_handle(w);
    if (!hwnd)
        return -1;
    ShowWindow(hwnd, SW_RESTORE);
    return 0;
#elif defined(__APPLE__)
    void *ns_window = moonbit_window_native_handle(w);
    void *msgsend = moonbit_objc_msgsend_symbol();
    if (!ns_window || !msgsend)
        return -1;
    ((mb_objc_msgsend_id_arg_t)msgsend)((mb_id_t)ns_window, moonbit_sel_register_name("zoom:"), (mb_id_t)ns_window);
    return 0;
#else
    return -1;
#endif
}

MOONBIT_FFI_EXPORT int moonbit_wm_toggle_maximize_window(int window_id)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;
#ifdef _WIN32
    HWND hwnd = (HWND)moonbit_window_native_handle(w);
    if (!hwnd)
        return -1;
    ShowWindow(hwnd, IsZoomed(hwnd) ? SW_RESTORE : SW_MAXIMIZE);
    return 0;
#elif defined(__APPLE__)
    void *ns_window = moonbit_window_native_handle(w);
    void *msgsend = moonbit_objc_msgsend_symbol();
    if (!ns_window || !msgsend)
        return -1;
    ((mb_objc_msgsend_id_arg_t)msgsend)((mb_id_t)ns_window, moonbit_sel_register_name("zoom:"), (mb_id_t)ns_window);
    return 0;
#else
    return -1;
#endif
}

/*
 * 将窗口带到最前并获得键盘焦点（对应 Tauri 的 Window::set_focus / tao 的
 * set_focus）：
 * - macOS：先激活本进程为前台 app，再对窗口执行 makeKeyAndOrderFront:。
 * - Windows：SetForegroundWindow（最小化时先 SW_RESTORE）。
 * - Linux：未实现，返回 -1（与本文件其他窗口控制导出一致）。
 */
MOONBIT_FFI_EXPORT int moonbit_wm_focus_window(int window_id)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;
#ifdef _WIN32
    HWND hwnd = (HWND)moonbit_window_native_handle(w);
    if (!hwnd)
        return -1;
    if (IsIconic(hwnd))
        ShowWindow(hwnd, SW_RESTORE);
    SetForegroundWindow(hwnd);
    return 0;
#elif defined(__APPLE__)
    void *ns_window = moonbit_window_native_handle(w);
    void *msgsend = moonbit_objc_msgsend_symbol();
    if (!ns_window || !msgsend)
        return -1;
    if (((mb_objc_msgsend_int_ret_t)msgsend)(
            (mb_id_t)ns_window, moonbit_sel_register_name("isMiniaturized")))
        return 0; /* 最小化时不强抢焦点，与 tao set_focus 语义一致 */
    moonbit_macos_activate_app();
    ((mb_objc_msgsend_id_arg_t)msgsend)(
        (mb_id_t)ns_window, moonbit_sel_register_name("makeKeyAndOrderFront:"), (mb_id_t)ns_window);
    return 0;
#else
    (void)window_id;
    return -1;
#endif
}

MOONBIT_FFI_EXPORT int moonbit_wm_set_fullscreen_window(int window_id, int fullscreen)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;
#ifdef _WIN32
    HWND hwnd = (HWND)moonbit_window_native_handle(w);
    if (!hwnd)
        return -1;
    if (fullscreen)
    {
        ShowWindow(hwnd, SW_MAXIMIZE);
        w->fullscreen = 1;
    }
    else
    {
        ShowWindow(hwnd, SW_RESTORE);
        w->fullscreen = 0;
    }
    return 0;
#elif defined(__APPLE__)
    void *ns_window = moonbit_window_native_handle(w);
    void *msgsend = moonbit_objc_msgsend_symbol();
    if (!ns_window || !msgsend)
        return -1;
    mb_sel_t sel_style_mask = moonbit_sel_register_name("styleMask");
    mb_sel_t sel_toggle_fullscreen = moonbit_sel_register_name("toggleFullScreen:");
    if (!sel_style_mask || !sel_toggle_fullscreen)
        return -1;
    const unsigned long NSWindowStyleMaskFullScreen = 1UL << 14;
    unsigned long style = ((mb_objc_msgsend_u64_t)msgsend)((mb_id_t)ns_window, sel_style_mask);
    int is_fullscreen = (style & NSWindowStyleMaskFullScreen) ? 1 : 0;
    if ((fullscreen && !is_fullscreen) || (!fullscreen && is_fullscreen))
        ((mb_objc_msgsend_id_arg_t)msgsend)((mb_id_t)ns_window, sel_toggle_fullscreen, (mb_id_t)ns_window);
    w->fullscreen = fullscreen ? 1 : 0;
    return 0;
#else
    (void)fullscreen;
    return -1;
#endif
}

MOONBIT_FFI_EXPORT int moonbit_wm_toggle_fullscreen_window(int window_id)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w)
        return -1;
    int next = w->fullscreen ? 0 : 1;
    return moonbit_wm_set_fullscreen_window(window_id, next);
}

MOONBIT_FFI_EXPORT int moonbit_wm_start_drag_window(int window_id)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;
#ifdef _WIN32
    HWND hwnd = (HWND)moonbit_window_native_handle(w);
    if (!hwnd)
        return -1;
    ReleaseCapture();
    SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
    return 0;
#elif defined(__APPLE__)
    void *ns_window = moonbit_window_native_handle(w);
    void *msgsend = moonbit_objc_msgsend_symbol();
    if (!ns_window || !msgsend)
        return -1;
    mb_id_t ns_app = moonbit_objc_get_class("NSApplication");
    mb_sel_t sel_shared = moonbit_sel_register_name("sharedApplication");
    mb_sel_t sel_current_event = moonbit_sel_register_name("currentEvent");
    mb_sel_t sel_drag = moonbit_sel_register_name("performWindowDragWithEvent:");
    if (!ns_app || !sel_shared || !sel_current_event || !sel_drag)
        return -1;
    mb_id_t app = ((mb_objc_msgsend_id_ret_t)msgsend)(ns_app, sel_shared);
    if (!app)
        return -1;
    mb_id_t event = ((mb_objc_msgsend_id_ret_t)msgsend)(app, sel_current_event);
    if (!event)
        return -1;
    ((mb_objc_msgsend_id_arg_t)msgsend)((mb_id_t)ns_window, sel_drag, event);
    return 0;
#else
    return -1;
#endif
}

MOONBIT_FFI_EXPORT int moonbit_wm_close_window(int window_id)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;
#ifdef _WIN32
    HWND hwnd = (HWND)moonbit_window_native_handle(w);
    if (!hwnd)
        return -1;
    PostMessage(hwnd, WM_CLOSE, 0, 0);
    return 0;
#elif defined(__APPLE__)
    void *ns_window = moonbit_window_native_handle(w);
    void *msgsend = moonbit_objc_msgsend_symbol();
    if (!ns_window || !msgsend)
        return -1;
    mb_sel_t sel_close = moonbit_sel_register_name("close");
    mb_sel_t sel_perform_close = moonbit_sel_register_name("performClose:");
    if (sel_close)
        ((mb_objc_msgsend_u64_t)msgsend)((mb_id_t)ns_window, sel_close);
    else if (sel_perform_close)
        ((mb_objc_msgsend_id_arg_t)msgsend)((mb_id_t)ns_window, sel_perform_close, (mb_id_t)ns_window);
    else
        return -1;
    return 0;
#else
    return moonbit_wm_terminate_window(window_id);
#endif
}

/* ════════════════════════════════════════════════════════════════
   macOS 应用外观：单一 Dock 图标 + 标准菜单/快捷键 + 全局退出
   ════════════════════════════════════════════════════════════════
   Lepus 每个窗口是独立子进程，各自启动 NSApplication 并被 vendor
   设为 Regular 激活策略 → 多个 Dock 图标。这里让子进程改为 Prohibited
   （不占 Dock），由主进程声明 Regular 持有唯一图标。
   Cocoa 的快捷键全由主菜单驱动，无菜单则 Cmd+W/Q/M 及 Edit 系列全部失效，
   因此为每个窗口进程安装标准主菜单。
   Cmd+Q 走自定义 action → IPC 广播 "app-quit" → 主进程转发给所有子进程 →
   各自 webview_terminate 干净退出。
   ════════════════════════════════════════════════════════════════ */

#ifdef __APPLE__
/* NSMenuItem key-equivalent 默认修饰键即 Command；Redo 用 Command+Shift。 */
#define LEPUS_MOD_COMMAND (1UL << 20)
#define LEPUS_MOD_SHIFT (1UL << 17)

static void lepus_request_app_quit(void)
{
    if (g_wm.process_type == PROCESS_TYPE_MAIN)
    {
        /* 单进程模式（主进程持有本地窗口）：直接终止全部本地窗口。 */
        webview_t handles[64];
        int count = 0;
        pthread_mutex_lock(&g_wm.mutex);
        webview_window_t *w = g_wm.head;
        while (w && count < 64)
        {
            if (w->handle)
                handles[count++] = w->handle;
            w = w->next;
        }
        pthread_mutex_unlock(&g_wm.mutex);
        for (int i = 0; i < count; i++)
            webview_terminate(handles[i]);
    }
    else
    {
        /* 子进程：向主进程发 "app-quit" 事件，由主进程广播给全部窗口。 */
        int wid = -1;
        pthread_mutex_lock(&g_wm.mutex);
        if (g_wm.head)
            wid = g_wm.head->window_id;
        pthread_mutex_unlock(&g_wm.mutex);
        if (wid > 0)
        {
            ipc_message_t msg;
            memset(&msg, 0, sizeof(msg));
            msg.source_window_id = wid;
            msg.target_window_id = 0;
            msg.message_type = IPC_MSG_EVENT;
            msg.message_id = alloc_message_id();
            strncpy(msg.subtype, "app-quit", IPC_SUBTYPE_LEN - 1);
            msg.data = (char *)"{}";
            msg.data_length = 2;
            if (g_ipc_client.connected)
                ipc_send(g_ipc_client.socket_fd, &msg);
        }
    }
}

/* 菜单 Quit 动作的 IMP（C 函数，注册为 ObjC 方法 requestQuit:）。 */
static void lepus_menu_quit_imp(mb_id_t self, mb_sel_t cmd, mb_id_t sender)
{
    (void)self;
    (void)cmd;
    (void)sender;
    lepus_request_app_quit();
}

/* 返回单例 LepusMenuHelper 实例（注册 ObjC 类一次）。 */
static mb_id_t lepus_menu_helper_instance(void)
{
    static mb_id_t instance = NULL;
    if (instance)
        return instance;

    void *lib = dlopen("/usr/lib/libobjc.A.dylib", RTLD_LAZY);
    if (!lib)
        lib = dlopen("/usr/lib/libobjc.dylib", RTLD_LAZY);
    if (!lib)
        return NULL;

    /* objc 运行时符号（stub.c 以纯 C 编译，不能直接用 Class/SEL/IMP 类型，
     * 全部走 void* + dlsym）。 */
    typedef void *(*objc_alloc_class_t)(void *, const char *, size_t);
    typedef int (*objc_add_method_t)(void *, void *, void *, const char *);
    typedef void (*objc_register_class_t)(void *);
    objc_alloc_class_t p_alloc = (objc_alloc_class_t)dlsym(lib, "objc_allocateClassPair");
    objc_add_method_t p_add = (objc_add_method_t)dlsym(lib, "class_addMethod");
    objc_register_class_t p_reg = (objc_register_class_t)dlsym(lib, "objc_registerClassPair");
    if (!p_alloc || !p_add || !p_reg)
        return NULL;

    const char *class_name = "LepusMenuHelper";
    void *cls = moonbit_objc_get_class(class_name);
    if (!cls)
    {
        void *nsobj = moonbit_objc_get_class("NSObject");
        if (!nsobj)
            return NULL;
        cls = p_alloc(nsobj, class_name, 0);
        if (!cls)
            return NULL;
        mb_sel_t sel_quit = moonbit_sel_register_name("requestQuit:");
        if (!sel_quit || !p_add(cls, sel_quit, (void *)lepus_menu_quit_imp, "v@:@"))
            return NULL;
        p_reg(cls);
    }

    void *msgsend = moonbit_objc_msgsend_symbol();
    if (!msgsend)
        return NULL;
    mb_sel_t sel_alloc = moonbit_sel_register_name("alloc");
    mb_sel_t sel_init = moonbit_sel_register_name("init");
    mb_id_t obj = ((mb_objc_msgsend_id_ret_t)msgsend)((mb_id_t)cls, sel_alloc);
    if (obj)
        obj = ((mb_objc_msgsend_id_ret_t)msgsend)(obj, sel_init);
    instance = obj;
    return instance;
}

static mb_id_t lepus_menu_make(const char *title, void *msgsend)
{
    mb_id_t ns_str_cls = moonbit_objc_get_class("NSString");
    mb_sel_t sel_with_utf8 = moonbit_sel_register_name("stringWithUTF8String:");
    mb_id_t title_str = ((mb_objc_msgsend_cstr_arg_ret_t)msgsend)(ns_str_cls, sel_with_utf8, title);
    mb_id_t menu_cls = moonbit_objc_get_class("NSMenu");
    mb_sel_t sel_alloc = moonbit_sel_register_name("alloc");
    mb_sel_t sel_init_title = moonbit_sel_register_name("initWithTitle:");
    mb_id_t menu = ((mb_objc_msgsend_id_ret_t)msgsend)(menu_cls, sel_alloc);
    if (menu && sel_init_title)
        ((mb_objc_msgsend_id_arg_t)msgsend)(menu, sel_init_title, title_str);
    return menu;
}

static mb_id_t lepus_menu_item(const char *title, const char *action_name,
                               const char *key_eq, mb_id_t target,
                               unsigned long mod_mask, void *msgsend)
{
    mb_id_t ns_str_cls = moonbit_objc_get_class("NSString");
    mb_sel_t sel_with_utf8 = moonbit_sel_register_name("stringWithUTF8String:");
    mb_id_t title_str = ((mb_objc_msgsend_cstr_arg_ret_t)msgsend)(ns_str_cls, sel_with_utf8, title);
    mb_id_t key_str = ((mb_objc_msgsend_cstr_arg_ret_t)msgsend)(ns_str_cls, sel_with_utf8, key_eq);
    mb_id_t item_cls = moonbit_objc_get_class("NSMenuItem");
    mb_sel_t sel_alloc = moonbit_sel_register_name("alloc");
    mb_sel_t sel_init = moonbit_sel_register_name("initWithTitle:action:keyEquivalent:");
    mb_sel_t sel_action = moonbit_sel_register_name(action_name);
    mb_id_t item = ((mb_objc_msgsend_id_ret_t)msgsend)(item_cls, sel_alloc);
    if (!item || !sel_init || !sel_action)
        return NULL;
    item = ((mb_objc_msgsend_id_sel_id_arg_ret_t)msgsend)(item, sel_init, title_str, sel_action, key_str);
    if (target)
    {
        mb_sel_t sel_set_target = moonbit_sel_register_name("setTarget:");
        ((mb_objc_msgsend_id_arg_t)msgsend)(item, sel_set_target, target);
    }
    if (mod_mask)
    {
        mb_sel_t sel_set_mask = moonbit_sel_register_name("setKeyEquivalentModifierMask:");
        ((mb_objc_msgsend_u64_arg_t)msgsend)(item, sel_set_mask, mod_mask);
    }
    return item;
}

static void lepus_menu_add_item(mb_id_t menu, mb_id_t item, void *msgsend)
{
    mb_sel_t sel_add = moonbit_sel_register_name("addItem:");
    ((mb_objc_msgsend_id_arg_t)msgsend)(menu, sel_add, item);
}

static mb_id_t lepus_menu_separator(void *msgsend)
{
    mb_id_t item_cls = moonbit_objc_get_class("NSMenuItem");
    mb_sel_t sel_sep = moonbit_sel_register_name("separatorItem");
    return ((mb_objc_msgsend_id_ret_t)msgsend)(item_cls, sel_sep);
}

static void lepus_menu_add_submenu(mb_id_t main_menu, mb_id_t submenu,
                                   void *msgsend)
{
    mb_id_t item_cls = moonbit_objc_get_class("NSMenuItem");
    mb_sel_t sel_alloc = moonbit_sel_register_name("alloc");
    mb_sel_t sel_init = moonbit_sel_register_name("init");
    mb_sel_t sel_set_submenu = moonbit_sel_register_name("setSubmenu:");
    mb_sel_t sel_add = moonbit_sel_register_name("addItem:");
    mb_id_t item = ((mb_objc_msgsend_id_ret_t)msgsend)(item_cls, sel_alloc);
    if (item && sel_init)
        item = ((mb_objc_msgsend_id_ret_t)msgsend)(item, sel_init);
    if (item && sel_set_submenu)
        ((mb_objc_msgsend_id_arg_t)msgsend)(item, sel_set_submenu, submenu);
    if (item && sel_add)
        ((mb_objc_msgsend_id_arg_t)msgsend)(main_menu, sel_add, item);
}
#endif /* __APPLE__ */

MOONBIT_FFI_EXPORT int moonbit_wm_set_activation_policy(int policy)
{
#ifdef __APPLE__
    void *msgsend = moonbit_objc_msgsend_symbol();
    if (!msgsend)
        return -1;
    mb_id_t app_cls = moonbit_objc_get_class("NSApplication");
    mb_sel_t sel_shared = moonbit_sel_register_name("sharedApplication");
    mb_sel_t sel_set_policy = moonbit_sel_register_name("setActivationPolicy:");
    mb_id_t app = ((mb_objc_msgsend_id_ret_t)msgsend)(app_cls, sel_shared);
    if (!app || !sel_set_policy)
        return -1;
    ((mb_objc_msgsend_u64_arg_t)msgsend)(app, sel_set_policy, (unsigned long)policy);
    return 0;
#else
    (void)policy;
    return 0;
#endif
}

MOONBIT_FFI_EXPORT int moonbit_wm_install_default_app_menu(void)
{
#ifdef __APPLE__
    void *msgsend = moonbit_objc_msgsend_symbol();
    if (!msgsend)
        return -1;
    mb_id_t app_cls = moonbit_objc_get_class("NSApplication");
    mb_sel_t sel_shared = moonbit_sel_register_name("sharedApplication");
    mb_sel_t sel_set_main = moonbit_sel_register_name("setMainMenu:");
    mb_id_t app = ((mb_objc_msgsend_id_ret_t)msgsend)(app_cls, sel_shared);
    if (!app || !sel_set_main)
        return -1;

    mb_id_t helper = lepus_menu_helper_instance();

    mb_id_t main_menu = lepus_menu_make("Main", msgsend);

    mb_id_t app_menu = lepus_menu_make("Lepus", msgsend);
    lepus_menu_add_item(app_menu,
        lepus_menu_item("Quit Lepus", "requestQuit:", "q", helper, 0, msgsend),
        msgsend);
    lepus_menu_add_submenu(main_menu, app_menu, msgsend);

    mb_id_t edit_menu = lepus_menu_make("Edit", msgsend);
    lepus_menu_add_item(edit_menu, lepus_menu_item("Undo", "undo:", "z", NULL, 0, msgsend), msgsend);
    lepus_menu_add_item(edit_menu, lepus_menu_item("Redo", "redo:", "z", NULL,
        LEPUS_MOD_COMMAND | LEPUS_MOD_SHIFT, msgsend), msgsend);
    lepus_menu_add_item(edit_menu, lepus_menu_separator(msgsend), msgsend);
    lepus_menu_add_item(edit_menu, lepus_menu_item("Cut", "cut:", "x", NULL, 0, msgsend), msgsend);
    lepus_menu_add_item(edit_menu, lepus_menu_item("Copy", "copy:", "c", NULL, 0, msgsend), msgsend);
    lepus_menu_add_item(edit_menu, lepus_menu_item("Paste", "paste:", "v", NULL, 0, msgsend), msgsend);
    lepus_menu_add_item(edit_menu, lepus_menu_item("Select All", "selectAll:", "a", NULL, 0, msgsend), msgsend);
    lepus_menu_add_submenu(main_menu, edit_menu, msgsend);

    mb_id_t win_menu = lepus_menu_make("Window", msgsend);
    lepus_menu_add_item(win_menu, lepus_menu_item("Close Window", "performClose:", "w", NULL, 0, msgsend), msgsend);
    lepus_menu_add_item(win_menu, lepus_menu_item("Minimize", "performMiniaturize:", "m", NULL, 0, msgsend), msgsend);
    lepus_menu_add_item(win_menu, lepus_menu_item("Zoom", "zoom:", "", NULL, 0, msgsend), msgsend);
    lepus_menu_add_submenu(main_menu, win_menu, msgsend);

    ((mb_objc_msgsend_id_arg_t)msgsend)(app, sel_set_main, main_menu);
    return 0;
#else
    return 0;
#endif
}

MOONBIT_FFI_EXPORT int moonbit_wm_set_devtools(int window_id, int enabled)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;
    if (!enabled)
        return 0;

#ifdef _WIN32
    webview_init(
        w->handle,
        "(function(){if(window.__LEPUS_DEVTOOLS_READY__)return;"
        "window.__LEPUS_DEVTOOLS_READY__=true;"
        "const open=()=>{try{window.chrome&&window.chrome.webview&&window.chrome.webview.openDevTools&&window.chrome.webview.openDevTools();}catch(_){}};"
        "window.addEventListener('DOMContentLoaded',open,{once:true});"
        "document.addEventListener('contextmenu',()=>{open();},true);"
        "open();})();");
    return 0;
#elif defined(__APPLE__)
#if !defined(NDEBUG)
    void *ns_window = moonbit_window_native_handle(w);
    void *msgsend = moonbit_objc_msgsend_symbol();
    if (!ns_window || !msgsend)
        return -1;
    mb_sel_t sel_content_view = moonbit_sel_register_name("contentView");
    if (!sel_content_view)
        return -1;
    mb_id_t content_view = ((mb_objc_msgsend_id_ret_t)msgsend)((mb_id_t)ns_window, sel_content_view);
    if (!content_view)
        return -1;
    mb_id_t wk = moonbit_find_wk_webview(content_view, msgsend);
    if (!wk)
        return -1;

    mb_sel_t sel_set_inspectable = moonbit_sel_register_name("setInspectable:");
    if (sel_set_inspectable)
        ((mb_objc_msgsend_int_arg_t)msgsend)(wk, sel_set_inspectable, 1);

    mb_sel_t sel_inspector = moonbit_sel_register_name("_inspector");
    mb_sel_t sel_show = moonbit_sel_register_name("show");
    if (sel_inspector && sel_show)
    {
        mb_id_t inspector = ((mb_objc_msgsend_id_ret_t)msgsend)(wk, sel_inspector);
        if (inspector)
            ((mb_objc_msgsend_u64_t)msgsend)(inspector, sel_show);
    }
    return 0;
#else
    (void)enabled;
    return 0;
#endif
#else
    (void)enabled;
    return 0;
#endif
}

MOONBIT_FFI_EXPORT int moonbit_wm_navigate(int window_id, const char *url)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;

    strncpy(w->url, url, sizeof(w->url) - 1);
    webview_navigate(w->handle, url);
    return 0;
}

MOONBIT_FFI_EXPORT int moonbit_wm_set_html(int window_id, const char *html)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;

    webview_set_html(w->handle, html);
    return 0;
}

MOONBIT_FFI_EXPORT int moonbit_wm_eval_js(int window_id, const char *js)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    int is_running = w && w->state == WINDOW_STATE_RUNNING;
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;

    if (is_running)
    {
        eval_js_ctx_t *ctx = (eval_js_ctx_t *)malloc(sizeof(eval_js_ctx_t));
        if (!ctx)
            return -1;
        ctx->js = dup_cstr(js);
        if (!ctx->js)
        {
            free(ctx);
            return -1;
        }

        if (wm_dispatch(window_id, eval_js_trampoline, ctx) != 0)
        {
            free(ctx->js);
            free(ctx);
            return -1;
        }
        return 0;
    }

    return webview_eval(w->handle, js);
}

MOONBIT_FFI_EXPORT int moonbit_wm_init_js(int window_id, const char *js)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;

    webview_init(w->handle, js);
    return 0;
}

MOONBIT_FFI_EXPORT int moonbit_wm_return_raw(
    int window_id,
    const char *seq,
    int status,
    const char *result)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    int is_running = w && w->state == WINDOW_STATE_RUNNING;
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w || !w->handle)
        return -1;

    if (!is_running)
    {
        webview_return(w->handle, seq, status, result);
        return 0;
    }

    return_raw_ctx_t *ctx = (return_raw_ctx_t *)malloc(sizeof(return_raw_ctx_t));
    if (!ctx)
        return -1;
    ctx->seq = dup_cstr(seq);
    ctx->result = dup_cstr(result);
    ctx->status = status;
    if (!ctx->seq || !ctx->result)
    {
        free(ctx->seq);
        free(ctx->result);
        free(ctx);
        return -1;
    }

    if (wm_dispatch(window_id, return_raw_trampoline, ctx) != 0)
    {
        free(ctx->seq);
        free(ctx->result);
        free(ctx);
        return -1;
    }
    return 0;
}

/* ════════════════════════════════════════════════════════════════
   MoonBit FFI 导出 —— 窗口可见性
   ════════════════════════════════════════════════════════════════ */

/**
 * 设置窗口可见性（供 binding.mbt 调用）。
 * visible = 1 显示，visible = 0 隐藏。
 * 注意：libwebview 不直接暴露 show/hide；通过 dispatch + 平台 API 实现。
 * 此处记录状态并触发事件；平台级实现可在上层 MoonBit 代码中扩展。
 */
MOONBIT_FFI_EXPORT int moonbit_webview_set_window_visibility(int window_id, int visible)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    pthread_mutex_unlock(&g_wm.mutex);
    if (!w)
        return -1;

    w->visible = visible ? 1 : 0;
    w->state = visible ? WINDOW_STATE_RUNNING : WINDOW_STATE_HIDDEN;
    fire_window_event(w, visible ? WINDOW_EVT_SHOWN : WINDOW_EVT_HIDDEN, NULL);

    /*
     * 原生显隐（对应 tao 的 set_visible）：
     *   show → 排到最前并成为 key window（但不激活 app，激活是 focus 的职责）；
     *   hide → orderOut / SW_HIDE。
     * 远端子进程窗口节点（handle == NULL）只做记账，原生操作由子进程内的
     * window_controls 命令执行。
     */
    if (w->handle)
    {
#ifdef _WIN32
        HWND hwnd = (HWND)moonbit_window_native_handle(w);
        if (hwnd)
            ShowWindow(hwnd, visible ? SW_SHOW : SW_HIDE);
#elif defined(__APPLE__)
        void *ns_window = moonbit_window_native_handle(w);
        void *msgsend = moonbit_objc_msgsend_symbol();
        if (ns_window && msgsend)
        {
            ((mb_objc_msgsend_id_arg_t)msgsend)(
                (mb_id_t)ns_window,
                moonbit_sel_register_name(visible ? "makeKeyAndOrderFront:" : "orderOut:"),
                (mb_id_t)ns_window);
        }
#endif
    }
    return 0;
}

/** 获取窗口可见状态；未找到返回 -1。 */
MOONBIT_FFI_EXPORT int moonbit_webview_get_window_visibility(int window_id)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    int vis = w ? w->visible : -1;
    pthread_mutex_unlock(&g_wm.mutex);
    return vis;
}

/* ════════════════════════════════════════════════════════════════
   MoonBit FFI 导出 —— 多进程支持
   ════════════════════════════════════════════════════════════════ */

/**
 * fork 出一个子进程，在其中创建并运行窗口。
 * 父进程立即返回子进程 PID（>0）；子进程不返回（退出时调用 exit(0)）。
 * 失败返回 -1。
 */
MOONBIT_FFI_EXPORT int moonbit_wm_create_child_window(
    const char *title,
    const char *url,
    int width, int height,
    int parent_window_id)
{
#ifdef _WIN32
    (void)title;
    (void)url;
    (void)width;
    (void)height;
    (void)parent_window_id;
    fprintf(stderr, "[WM] moonbit_wm_create_child_window is not supported on WIN32; use spawn/connect flow instead\n");
    return -1;
#else
    pid_t pid = fork();
    if (pid < 0)
    {
        perror("[WM] fork");
        return -1;
    }

    if (pid == 0)
    {
        /* ── 子进程 ─────────────────────────────────────────────── */
        /* 重置全局状态（fork 后继承了父进程的内存快照） */
        g_wm.initialized = 0;
        g_wm.process_type = PROCESS_TYPE_CHILD;
        g_wm.head = g_wm.tail = NULL;
        g_wm.window_count = 0;
        g_wm.ipc_server_running = 0;
        g_ipc_client.connected = 0;

        /* 连接到父进程 IPC 服务器 */
        socket_handle_t sock = connect_to_ipc_server();
        if (sock == IPC_INVALID_SOCKET)
        {
            fprintf(stderr, "[WM-child] IPC connect failed\n");
            exit(1);
        }

        g_ipc_client.socket_fd = sock;
        g_ipc_client.connected = 1;
        g_ipc_client.state = IPC_CONN_CONNECTED;

        /* 初始化子进程窗口管理器（不启动 IPC 服务器） */
        moonbit_wm_init(0);

        pthread_create(&g_ipc_client.listener_thread, NULL, ipc_client_listener, NULL);

        /* 创建窗口 */
        int wid = moonbit_wm_create_window(title, url, width, height,
                                           0, 0, 0, 0, parent_window_id);
        if (wid < 0)
        {
            fprintf(stderr, "[WM-child] create_window failed\n");
            exit(1);
        }

        g_ipc_client.window_id = wid;

        /* 向主进程发送注册事件 */
        char payload[256];
        snprintf(payload, sizeof(payload),
                 "{\"window_id\":%d,\"pid\":%d,\"parent_id\":%d,\"title\":\"%s\"}",
                 wid, moonbit_wm_get_process_id(), parent_window_id, title ? title : "");

        ipc_message_t reg = {0};
        reg.source_window_id = wid;
        reg.target_window_id = 0;
        reg.message_type = IPC_MSG_EVENT;
        reg.message_id = ++g_ipc_client.message_seq;
        strncpy(reg.subtype, "window_registered", IPC_SUBTYPE_LEN - 1);
        reg.data = payload;
        reg.data_length = (int32_t)strlen(payload);
        ipc_send(sock, &reg);

        /* 运行事件循环（阻塞直到窗口关闭） */
        moonbit_wm_run_window(wid);

        /* 清理并退出 */
        moonbit_wm_destroy_window(wid);
        moonbit_wm_cleanup();
        exit(0);
    }

    /* ── 父进程：返回子 PID ─────────────────────────────────────── */
    return (int)pid;
#endif
}

MOONBIT_FFI_EXPORT int moonbit_wm_fork_process(void)
{
#ifdef _WIN32
    fprintf(stderr, "[WM] moonbit_wm_fork_process is not supported on WIN32; use moonbit_wm_spawn_process instead\n");
    return -1;
#else
    if (!g_wm.initialized)
    {
        if (moonbit_wm_init(1) != 0)
            return -1;
    }

    pid_t pid = fork();
    if (pid < 0)
    {
        perror("[WM] fork");
        return -1;
    }

    if (pid == 0)
    {
        g_wm.initialized = 0;
        g_wm.process_type = PROCESS_TYPE_CHILD;
        g_wm.head = g_wm.tail = NULL;
        g_wm.window_count = 0;
        g_wm.next_window_id = 1;
        g_wm.ipc_server_running = 0;
        g_wm.on_ipc_message = NULL;
        g_ipc_client.connected = 0;

        socket_handle_t sock = connect_to_ipc_server();
        if (sock == IPC_INVALID_SOCKET)
        {
            fprintf(stderr, "[WM-child] IPC connect failed\n");
            exit(1);
        }

        g_ipc_client.socket_fd = sock;
        g_ipc_client.connected = 1;
        g_ipc_client.state = IPC_CONN_CONNECTED;

        if (moonbit_wm_init(0) != 0)
        {
            fprintf(stderr, "[WM-child] init failed\n");
            exit(1);
        }

        pthread_create(&g_ipc_client.listener_thread, NULL, ipc_client_listener, NULL);
        return 0;
    }

    return (int)pid;
#endif
}

MOONBIT_FFI_EXPORT int moonbit_wm_spawn_process(
    const char *program,
    const char *arg1)
{
    if (!program || !program[0])
        return -1;

#ifdef _WIN32
    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    char command_line[2048];
    const char *extra_arg = (arg1 && arg1[0]) ? arg1 : NULL;

    memset(&si, 0, sizeof(si));
    memset(&pi, 0, sizeof(pi));
    si.cb = sizeof(si);

    if (extra_arg)
        _snprintf(command_line, sizeof(command_line), "\"%s\" \"%s\"", program, extra_arg);
    else
        _snprintf(command_line, sizeof(command_line), "\"%s\"", program);
    command_line[sizeof(command_line) - 1] = '\0';

    if (!CreateProcessA(
            program,
            command_line,
            NULL,
            NULL,
            TRUE,
            0,
            NULL,
            NULL,
            &si,
            &pi))
    {
        fprintf(stderr, "[WM] CreateProcess failed: %lu\n", (unsigned long)GetLastError());
        return -1;
    }

    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return (int)pi.dwProcessId;
#else
    pid_t pid = 0;
    char *const argv[] = {
        (char *)program,
        (char *)(arg1 && arg1[0] ? arg1 : NULL),
        NULL};

    int rc = posix_spawn(&pid, program, NULL, NULL, argv, environ);
    if (rc != 0)
    {
        errno = rc;
        perror("[WM] posix_spawn");
        return -1;
    }
    return (int)pid;
#endif
}

MOONBIT_FFI_EXPORT int moonbit_wm_connect_child_process(void)
{
    g_wm.initialized = 0;
    g_wm.process_type = PROCESS_TYPE_CHILD;
    g_wm.head = g_wm.tail = NULL;
    g_wm.window_count = 0;
    g_wm.next_window_id = 1;
    g_wm.ipc_server_running = 0;
    g_wm.on_ipc_message = NULL;
    g_ipc_client.connected = 0;

    socket_handle_t sock = connect_to_ipc_server();
    if (sock == IPC_INVALID_SOCKET)
    {
        fprintf(stderr, "[WM-child] IPC connect failed\n");
        return -1;
    }

    g_ipc_client.socket_fd = sock;
    g_ipc_client.connected = 1;
    g_ipc_client.state = IPC_CONN_CONNECTED;

    if (moonbit_wm_init(0) != 0)
        return -1;

    pthread_create(&g_ipc_client.listener_thread, NULL, ipc_client_listener, NULL);
    return 0;
}

/**
 * 设置当前（子）进程的窗口 ID 起始值。
 *
 * 在多进程多窗口场景下，主进程为每个子进程分配一个全局唯一的起始 id，
 * 子进程在 connect 之后、创建窗口之前调用本函数，保证各子进程分配的
 * window_id 互不冲突（IPC 通过 window_id 路由到具体窗口）。
 *
 * 返回 0 成功，-1 失败（base 非法）。
 */
MOONBIT_FFI_EXPORT int moonbit_wm_set_window_id_base(int base)
{
    if (base < 1)
        return -1;
    g_wm.next_window_id = base;
    return 0;
}

/** 阻塞等待子进程结束；status 接收退出状态（可为 NULL）。 */
static int moonbit_wm_wait_child(int pid, int *status)
{
#ifdef _WIN32
    HANDLE process = OpenProcess(SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, FALSE, (DWORD)pid);
    if (!process)
        return -1;
    DWORD wait_rc = WaitForSingleObject(process, INFINITE);
    if (wait_rc != WAIT_OBJECT_0)
    {
        CloseHandle(process);
        return -1;
    }
    if (status)
    {
        DWORD exit_code = 0;
        if (!GetExitCodeProcess(process, &exit_code))
            *status = -1;
        else
            *status = (int)exit_code;
    }
    CloseHandle(process);
    return pid;
#else
    return (int)waitpid((pid_t)pid, status, 0);
#endif
}

/** 非阻塞检查子进程；尚未结束返回 0，已结束返回 PID，错误返回 -1。 */
static int moonbit_wm_wait_child_noblock(int pid, int *status)
{
#ifdef _WIN32
    HANDLE process = OpenProcess(SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, FALSE, (DWORD)pid);
    if (!process)
        return -1;
    DWORD wait_rc = WaitForSingleObject(process, 0);
    if (wait_rc == WAIT_TIMEOUT)
    {
        CloseHandle(process);
        return 0;
    }
    if (wait_rc != WAIT_OBJECT_0)
    {
        CloseHandle(process);
        return -1;
    }
    if (status)
    {
        DWORD exit_code = 0;
        if (!GetExitCodeProcess(process, &exit_code))
            *status = -1;
        else
            *status = (int)exit_code;
    }
    CloseHandle(process);
    return pid;
#else
    return (int)waitpid((pid_t)pid, status, WNOHANG);
#endif
}

MOONBIT_FFI_EXPORT int moonbit_wm_wait_child_noblock_no_status(int pid)
{
    return moonbit_wm_wait_child_noblock(pid, NULL);
}

/** 向子进程发送 SIGTERM。 */
MOONBIT_FFI_EXPORT int moonbit_wm_kill_child(int pid)
{
#ifdef _WIN32
    HANDLE process = OpenProcess(PROCESS_TERMINATE, FALSE, (DWORD)pid);
    if (!process)
        return -1;
    BOOL ok = TerminateProcess(process, 1);
    CloseHandle(process);
    return ok ? 0 : -1;
#else
    return kill((pid_t)pid, SIGTERM);
#endif
}

/** 返回当前进程类型：0 = 主进程，1 = 子进程。 */
MOONBIT_FFI_EXPORT int moonbit_wm_get_process_type(void)
{
    return (int)g_wm.process_type;
}

/** 返回当前进程 PID。 */
MOONBIT_FFI_EXPORT int moonbit_wm_get_process_id(void)
{
#ifdef _WIN32
    return (int)GetCurrentProcessId();
#else
    return (int)getpid();
#endif
}

/* ════════════════════════════════════════════════════════════════
   MoonBit FFI 导出 —— IPC 通信
   ════════════════════════════════════════════════════════════════ */

/**
 * 发送 IPC 消息（fire-and-forget）。
 * target_window_id = 0 → 广播给所有已连接的子进程窗口。
 * 返回 0 成功，-1 失败。
 */
MOONBIT_FFI_EXPORT int moonbit_wm_ipc_send(
    int source_window_id,
    int target_window_id,
    int message_type,
    const char *subtype,
    const char *data)
{
    ipc_message_t msg;
    memset(&msg, 0, sizeof(msg));
    msg.source_window_id = source_window_id;
    msg.target_window_id = target_window_id;
    msg.message_type = (ipc_msg_type_t)message_type;
    msg.message_id = alloc_message_id();
    strncpy(msg.subtype, subtype ? subtype : "", IPC_SUBTYPE_LEN - 1);

    char *buf = NULL;
    if (data && data[0])
    {
        int len = (int)strlen(data);
        if (len > IPC_MAX_DATA - 1)
            len = IPC_MAX_DATA - 1;
        buf = (char *)malloc(len + 1);
        if (!buf)
            return -1;
        memcpy(buf, data, len);
        buf[len] = '\0';
        msg.data = buf;
        msg.data_length = len;
    }

    int rc = 0;

    if (g_wm.process_type == PROCESS_TYPE_CHILD)
    {
        /* 子进程：通过 IPC 客户端发送到主进程 */
        if (!g_ipc_client.connected || g_ipc_client.socket_fd == IPC_INVALID_SOCKET)
        {
            rc = -1;
        }
        else
        {
            rc = ipc_send(g_ipc_client.socket_fd, &msg);
        }
    }
    else
    {
        /* 主进程 */
        if (target_window_id == 0)
        {
            /* 广播 */
            pthread_mutex_lock(&g_wm.mutex);
            webview_window_t *w = g_wm.head;
            while (w)
            {
                if (w->ipc_client_fd != IPC_INVALID_SOCKET)
                    ipc_send(w->ipc_client_fd, &msg);
                w = w->next;
            }
            pthread_mutex_unlock(&g_wm.mutex);
        }
        else
        {
            pthread_mutex_lock(&g_wm.mutex);
            webview_window_t *w = find_window(target_window_id);
            socket_handle_t fd =
                (w && w->ipc_client_fd != IPC_INVALID_SOCKET) ? w->ipc_client_fd : IPC_INVALID_SOCKET;
            if (fd == IPC_INVALID_SOCKET && target_window_id >= 0 && target_window_id < g_remote_window_fds_capacity)
                fd = g_remote_window_fds[target_window_id];
            pthread_mutex_unlock(&g_wm.mutex);
            rc = (fd != IPC_INVALID_SOCKET) ? ipc_send(fd, &msg) : -1;
            if (rc != 0)
            {
                /* 定向发送失败通常意味着目标窗口尚未注册（fd 表无映射），
                 * 或连接已断开被清除；保留一条诊断日志便于排查。 */
                fprintf(stderr,
                        "[WM] ipc_send failed: target=%d type=%d sub=%s\n",
                        target_window_id, message_type,
                        msg.subtype);
                fflush(stderr);
            }
        }
    }

    free(buf);
    return rc;
}

/**
 * 发送 IPC 请求并同步等待响应（含超时）。
 * response_buf     — 调用方提供的缓冲区，接收响应数据。
 * response_buf_len — 缓冲区大小（字节）。
 * timeout_ms       — 最大等待时间（毫秒）；<=0 表示无限等待。
 * 返回响应数据字节数，超时或失败返回 -1。
 */
MOONBIT_FFI_EXPORT int moonbit_wm_ipc_request(
    int source_window_id,
    int target_window_id,
    const char *subtype,
    const char *data,
    char *response_buf,
    int response_buf_len,
    int timeout_ms)
{
    pthread_mutex_lock(&g_wm.request_mutex);

    ipc_message_t req;
    memset(&req, 0, sizeof(req));
    req.source_window_id = source_window_id;
    req.target_window_id = target_window_id;
    req.message_type = IPC_MSG_REQUEST;
    req.message_id = alloc_message_id();
    strncpy(req.subtype, subtype ? subtype : "", IPC_SUBTYPE_LEN - 1);

    char *buf = NULL;
    if (data && data[0])
    {
        int len = (int)strlen(data);
        if (len > IPC_MAX_DATA - 1)
            len = IPC_MAX_DATA - 1;
        buf = (char *)malloc(len + 1);
        if (!buf)
            return -1;
        memcpy(buf, data, len);
        buf[len] = '\0';
        req.data = buf;
        req.data_length = len;
    }

    /* 确定发送 fd */
    socket_handle_t fd = IPC_INVALID_SOCKET;
    if (g_wm.process_type == PROCESS_TYPE_CHILD)
    {
        fd = g_ipc_client.connected ? g_ipc_client.socket_fd : IPC_INVALID_SOCKET;
    }
    else
    {
        pthread_mutex_lock(&g_wm.mutex);
        webview_window_t *w = find_window(target_window_id);
        fd = (w && w->ipc_client_fd != IPC_INVALID_SOCKET) ? w->ipc_client_fd : IPC_INVALID_SOCKET;
        if (fd == IPC_INVALID_SOCKET && target_window_id >= 0 && target_window_id < g_remote_window_fds_capacity)
            fd = g_remote_window_fds[target_window_id];
        pthread_mutex_unlock(&g_wm.mutex);
    }

    if (fd == IPC_INVALID_SOCKET)
    {
        free(buf);
        pthread_mutex_unlock(&g_wm.request_mutex);
        return -1;
    }

    /* 注册等待槽 */
    ipc_message_t response;
    memset(&response, 0, sizeof(response));

    pthread_mutex_lock(&g_wm.response_mutex);
    g_wm.pending_response = &response;
    g_wm.pending_msg_id = req.message_id;

    /* 发送请求 */
    if (ipc_send(fd, &req) < 0)
    {
        g_wm.pending_response = NULL;
        g_wm.pending_msg_id = -1;
        pthread_mutex_unlock(&g_wm.response_mutex);
        free(buf);
        pthread_mutex_unlock(&g_wm.request_mutex);
        return -1;
    }
    free(buf);

    /* 等待响应 */
    int wait_rc = 0;
    if (timeout_ms > 0)
    {
        struct timespec ts;
        clock_gettime(CLOCK_REALTIME, &ts);
        ts.tv_sec += timeout_ms / 1000;
        ts.tv_nsec += (timeout_ms % 1000) * 1000000L;
        if (ts.tv_nsec >= 1000000000L)
        {
            ts.tv_sec++;
            ts.tv_nsec -= 1000000000L;
        }

        while (response.message_id != req.message_id && wait_rc == 0)
        {
            wait_rc = pthread_cond_timedwait(&g_wm.response_cond,
                                             &g_wm.response_mutex, &ts);
        }
    }
    else
    {
        while (response.message_id != req.message_id)
        {
            pthread_cond_wait(&g_wm.response_cond, &g_wm.response_mutex);
        }
    }

    g_wm.pending_response = NULL;
    g_wm.pending_msg_id = -1;
    pthread_mutex_unlock(&g_wm.response_mutex);

    if (wait_rc != 0 || response.message_id != req.message_id)
    {
        ipc_message_free(&response);
        pthread_mutex_unlock(&g_wm.request_mutex);
        return -1; /* 超时或中断 */
    }

    /* 复制响应数据 */
    int copy_len = 0;
    if (response.data && response.data_length > 0 &&
        response_buf && response_buf_len > 0)
    {
        copy_len = response.data_length < response_buf_len - 1
                       ? response.data_length
                       : response_buf_len - 1;
        memcpy(response_buf, response.data, copy_len);
        response_buf[copy_len] = '\0';
    }

    ipc_message_free(&response);
    pthread_mutex_unlock(&g_wm.request_mutex);
    return copy_len;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t moonbit_wm_ipc_request_bytes(
    int source_window_id,
    int target_window_id,
    const char *subtype,
    const char *data,
    int timeout_ms)
{
    char response_buf[IPC_MAX_DATA + 1];
    int len = moonbit_wm_ipc_request(
        source_window_id,
        target_window_id,
        subtype,
        data,
        response_buf,
        sizeof(response_buf),
        timeout_ms);
    if (len <= 0)
        return moonbit_make_bytes_raw(0);
    moonbit_bytes_t result = moonbit_make_bytes_raw((int32_t)len);
    memcpy(result, response_buf, (size_t)len);
    return result;
}

/**
 * 发送 IPC 响应（将 request_id 原样填入 message_id，供请求方匹配）。
 */
MOONBIT_FFI_EXPORT int moonbit_wm_ipc_respond(
    int source_window_id,
    int target_window_id,
    int request_id,
    const char *data)
{
    ipc_message_t msg;
    memset(&msg, 0, sizeof(msg));
    msg.source_window_id = source_window_id;
    msg.target_window_id = target_window_id;
    msg.message_type = IPC_MSG_RESPONSE;
    msg.message_id = request_id;
    strncpy(msg.subtype, "response", IPC_SUBTYPE_LEN - 1);

    char *buf = NULL;
    if (data && data[0])
    {
        int len = (int)strlen(data);
        if (len > IPC_MAX_DATA - 1)
            len = IPC_MAX_DATA - 1;
        buf = (char *)malloc(len + 1);
        if (!buf)
            return -1;
        memcpy(buf, data, len);
        buf[len] = '\0';
        msg.data = buf;
        msg.data_length = len;
    }

    int rc = 0;
    if (g_wm.process_type == PROCESS_TYPE_CHILD)
    {
        rc = (g_ipc_client.connected && g_ipc_client.socket_fd != IPC_INVALID_SOCKET)
                 ? ipc_send(g_ipc_client.socket_fd, &msg)
                 : -1;
    }
    else
    {
        pthread_mutex_lock(&g_wm.mutex);
        webview_window_t *w = find_window(target_window_id);
        socket_handle_t fd =
            (w && w->ipc_client_fd != IPC_INVALID_SOCKET) ? w->ipc_client_fd : IPC_INVALID_SOCKET;
        if (fd == IPC_INVALID_SOCKET && target_window_id >= 0 && target_window_id < g_remote_window_fds_capacity)
            fd = g_remote_window_fds[target_window_id];
        pthread_mutex_unlock(&g_wm.mutex);
        rc = (fd != IPC_INVALID_SOCKET) ? ipc_send(fd, &msg) : -1;
    }

    free(buf);
    return rc;
}

/* ════════════════════════════════════════════════════════════════
   MoonBit FFI 导出 —— 窗口管理器查询
   ════════════════════════════════════════════════════════════════ */

/**
 * 获取指定窗口的 webview_t 句柄（供 binding.mbt 中未封装的 C API 调用）。
 * 返回句柄地址（int64 截断），未找到返回 0。
 */
MOONBIT_FFI_EXPORT void *moonbit_wm_get_handle(int window_id)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    void *h = w ? (void *)w->handle : NULL;
    pthread_mutex_unlock(&g_wm.mutex);
    return h;
}

/* ════════════════════════════════════════════════════════════════
   辅助：窗口 dispatch（跨线程安全调用 webview API）
   ════════════════════════════════════════════════════════════════ */

typedef struct
{
    void (*fn)(webview_t, void *);
    void *arg;
} dispatch_ctx_t;

static void dispatch_trampoline(webview_t w, void *arg)
{
    dispatch_ctx_t *ctx = (dispatch_ctx_t *)arg;
    ctx->fn(w, ctx->arg);
    free(ctx);
}

/**
 * 线程安全地向指定窗口的事件循环分派任务。
 */
static int wm_dispatch(
    int window_id,
    void (*fn)(webview_t, void *),
    void *arg)
{
    pthread_mutex_lock(&g_wm.mutex);
    webview_window_t *w = find_window(window_id);
    webview_t handle = w ? w->handle : NULL;
    pthread_mutex_unlock(&g_wm.mutex);
    if (!handle)
        return -1;

    dispatch_ctx_t *ctx = (dispatch_ctx_t *)malloc(sizeof(dispatch_ctx_t));
    if (!ctx)
        return -1;
    ctx->fn = fn;
    ctx->arg = arg;
    webview_dispatch(handle, dispatch_trampoline, ctx);
    return 0;
}

/* ─── IPC 消息接收（供 MoonBit 轮询） ─────────────────────────────── */

/* 每个窗口的 IPC 接收队列（单条消息缓冲） */
typedef struct ipc_recv_node
{
    ipc_message_t msg;
    struct ipc_recv_node *next;
} ipc_recv_node_t;

typedef struct
{
    ipc_recv_node_t *head;
    ipc_recv_node_t *tail;
    pthread_mutex_t mutex;
} ipc_recv_queue_t;

static ipc_recv_queue_t *g_recv_queue = NULL;
static int g_recv_queue_capacity = 0;
static pthread_mutex_t g_recv_queues_mutex = PTHREAD_MUTEX_INITIALIZER;

static ipc_recv_queue_t *get_recv_queue(int window_id)
{
    pthread_mutex_lock(&g_recv_queues_mutex);
    if (window_id < 0 || window_id >= g_recv_queue_capacity || !g_recv_queue)
    {
        pthread_mutex_unlock(&g_recv_queues_mutex);
        return NULL;
    }
    pthread_mutex_unlock(&g_recv_queues_mutex);
    return &g_recv_queue[window_id];
}

static void ensure_recv_queues(void)
{
    pthread_mutex_lock(&g_recv_queues_mutex);
    if (g_recv_queue_capacity < g_wm.next_window_id + 17)
    {
        int new_cap = g_recv_queue_capacity == 0 ? 32 : g_recv_queue_capacity * 2;
        if (new_cap < g_wm.next_window_id + 17)
            new_cap = g_wm.next_window_id + 17;
        ipc_recv_queue_t *new_q =
            (ipc_recv_queue_t *)realloc(g_recv_queue, new_cap * sizeof(ipc_recv_queue_t));
        if (new_q)
        {
            for (int i = g_recv_queue_capacity; i < new_cap; i++)
            {
                memset(&new_q[i], 0, sizeof(ipc_recv_queue_t));
                pthread_mutex_init(&new_q[i].mutex, NULL);
            }
            g_recv_queue = new_q;
            g_recv_queue_capacity = new_cap;
        }
    }
    pthread_mutex_unlock(&g_recv_queues_mutex);
}

/* 处理 "app-quit" 事件：
 * - 主进程：转发给全部子进程（各自 webview_terminate），并终止本地窗口；
 * - 子进程：终止本地窗口（run loop 退出 → 进程自然结束）。
 */
static void lepus_handle_app_quit_message(ipc_message_t *msg)
{
    webview_t handles[64];
    int count = 0;

    pthread_mutex_lock(&g_wm.mutex);
    if (g_wm.process_type == PROCESS_TYPE_MAIN)
    {
        for (int i = 0; i < g_remote_window_fds_capacity; i++)
        {
            if (g_remote_window_fds[i] != IPC_INVALID_SOCKET)
            {
                ipc_message_t fwd;
                memset(&fwd, 0, sizeof(fwd));
                fwd.source_window_id = msg->source_window_id;
                fwd.target_window_id = i;
                fwd.message_type = IPC_MSG_EVENT;
                fwd.message_id = msg->message_id;
                strncpy(fwd.subtype, "app-quit", IPC_SUBTYPE_LEN - 1);
                ipc_send(g_remote_window_fds[i], &fwd);
            }
        }
    }
    webview_window_t *w = g_wm.head;
    while (w && count < 64)
    {
        if (w->handle)
            handles[count++] = w->handle;
        w = w->next;
    }
    pthread_mutex_unlock(&g_wm.mutex);

    for (int i = 0; i < count; i++)
        webview_terminate(handles[i]);
}

/* IPC 消息回调：将消息放入窗口的接收队列
 *
 * 多窗口事件推送（push）在此实现：主进程定向发给子进程窗口的
 * `IPC_MSG_EVENT`（subtype = `lepus-event`）直接 eval 到该窗口，触发前端
 * CustomEvent("lepus_event")。消息的 `data` 字段即完整 JS 代码（由主进程
 * 侧构造），因此无需入队、也无需 MoonBit 侧后台轮询。
 */
static void ipc_recv_callback(ipc_message_t *msg)
{
    if (msg->target_window_id < 0)
        return;

    if (msg->message_type == IPC_MSG_EVENT &&
        strcmp(msg->subtype, "app-quit") == 0)
    {
        lepus_handle_app_quit_message(msg);
        return;
    }

    if (msg->message_type == IPC_MSG_EVENT &&
        strcmp(msg->subtype, "lepus-event") == 0 &&
        msg->data && msg->data_length > 0)
    {
        eval_js_ctx_t *ctx = (eval_js_ctx_t *)calloc(1, sizeof(eval_js_ctx_t));
        if (!ctx)
            return;
        ctx->js = dup_cstr(msg->data);
        if (!ctx->js)
        {
            free(ctx);
            return;
        }
        if (wm_dispatch(msg->target_window_id, eval_js_trampoline, ctx) != 0)
        {
            free(ctx->js);
            free(ctx);
        }
        return;
    }

    ipc_recv_queue_t *q = get_recv_queue(msg->target_window_id);
    if (!q)
        return;
    ipc_recv_node_t *node = (ipc_recv_node_t *)calloc(1, sizeof(ipc_recv_node_t));
    if (!node)
        return;
    node->msg.source_window_id = msg->source_window_id;
    node->msg.target_window_id = msg->target_window_id;
    node->msg.message_type = msg->message_type;
    node->msg.message_id = msg->message_id;
    strncpy(node->msg.subtype, msg->subtype, IPC_SUBTYPE_LEN - 1);
    if (msg->data && msg->data_length > 0)
    {
        node->msg.data = (char *)malloc((size_t)msg->data_length + 1);
        if (!node->msg.data)
        {
            free(node);
            return;
        }
        memcpy(node->msg.data, msg->data, (size_t)msg->data_length);
        node->msg.data[msg->data_length] = '\0';
        node->msg.data_length = msg->data_length;
    }
    pthread_mutex_lock(&q->mutex);
    if (!q->tail)
    {
        q->head = q->tail = node;
    }
    else
    {
        q->tail->next = node;
        q->tail = node;
    }
    pthread_mutex_unlock(&q->mutex);
}

static void ipc_wire_put_i32(unsigned char *dst, int32_t value)
{
    uint32_t v = (uint32_t)value;
    dst[0] = (unsigned char)(v & 0xffu);
    dst[1] = (unsigned char)((v >> 8) & 0xffu);
    dst[2] = (unsigned char)((v >> 16) & 0xffu);
    dst[3] = (unsigned char)((v >> 24) & 0xffu);
}

MOONBIT_FFI_EXPORT moonbit_bytes_t moonbit_wm_ipc_pop_message_wire(int window_id)
{
    moonbit_bytes_t empty = moonbit_make_bytes_raw(0);
    ensure_recv_queues();
    ipc_recv_queue_t *q = get_recv_queue(window_id);
    if (!q)
        return empty;

    pthread_mutex_lock(&q->mutex);
    if (!q->head)
    {
        pthread_mutex_unlock(&q->mutex);
        return empty;
    }
    ipc_recv_node_t *node = q->head;
    q->head = node->next;
    if (!q->head)
        q->tail = NULL;
    pthread_mutex_unlock(&q->mutex);

    ipc_message_t *msg = &node->msg;
    int32_t subtype_len = (int32_t)strlen(msg->subtype);
    int32_t data_len = msg->data ? msg->data_length : 0;
    int32_t wire_len = 24 + subtype_len + data_len;
    moonbit_bytes_t result = moonbit_make_bytes_raw(wire_len);
    unsigned char *out = (unsigned char *)result;
    ipc_wire_put_i32(out, msg->source_window_id);
    ipc_wire_put_i32(out + 4, msg->target_window_id);
    ipc_wire_put_i32(out + 8, (int32_t)msg->message_type);
    ipc_wire_put_i32(out + 12, msg->message_id);
    ipc_wire_put_i32(out + 16, subtype_len);
    ipc_wire_put_i32(out + 20, data_len);
    if (subtype_len > 0)
        memcpy(out + 24, msg->subtype, (size_t)subtype_len);
    if (data_len > 0)
        memcpy(out + 24 + subtype_len, msg->data, (size_t)data_len);
    ipc_message_free(msg);
    free(node);
    return result;
}
