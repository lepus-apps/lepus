#ifndef LEPUS_WEBVIEW_C_ABI_H
#define LEPUS_WEBVIEW_C_ABI_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include <time.h>
#include <limits.h>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <process.h>

typedef DWORD pid_t;
typedef SOCKET socket_handle_t;
typedef HANDLE pthread_t;
typedef SRWLOCK pthread_mutex_t;
typedef CONDITION_VARIABLE pthread_cond_t;

#define PTHREAD_MUTEX_INITIALIZER SRWLOCK_INIT
#define PTHREAD_COND_INITIALIZER CONDITION_VARIABLE_INIT
#define IPC_INVALID_SOCKET INVALID_SOCKET
#define UNUSED_ATTR
#define CLOCK_REALTIME 0

typedef struct
{
    void *(*start_routine)(void *);
    void *arg;
} moonbit_thread_start_ctx_t;

static unsigned __stdcall moonbit_thread_start(void *arg)
{
    moonbit_thread_start_ctx_t *ctx = (moonbit_thread_start_ctx_t *)arg;
    void *(*start_routine)(void *) = ctx->start_routine;
    void *start_arg = ctx->arg;
    free(ctx);
    start_routine(start_arg);
    return 0;
}

static int pthread_create(
    pthread_t *thread,
    void *unused_attr,
    void *(*start_routine)(void *),
    void *arg)
{
    (void)unused_attr;
    moonbit_thread_start_ctx_t *ctx =
        (moonbit_thread_start_ctx_t *)malloc(sizeof(moonbit_thread_start_ctx_t));
    if (!ctx)
        return ENOMEM;
    ctx->start_routine = start_routine;
    ctx->arg = arg;

    uintptr_t handle = _beginthreadex(NULL, 0, moonbit_thread_start, ctx, 0, NULL);
    if (handle == 0)
    {
        int err = errno ? errno : EAGAIN;
        free(ctx);
        return err;
    }
    *thread = (HANDLE)handle;
    return 0;
}

static int pthread_join(pthread_t thread, void **retval)
{
    (void)retval;
    DWORD rc = WaitForSingleObject(thread, INFINITE);
    CloseHandle(thread);
    return rc == WAIT_OBJECT_0 ? 0 : EINVAL;
}

static int pthread_detach(pthread_t thread)
{
    return CloseHandle(thread) ? 0 : EINVAL;
}

static int pthread_mutex_init(pthread_mutex_t *mutex, void *unused_attr)
{
    (void)unused_attr;
    InitializeSRWLock(mutex);
    return 0;
}

static int pthread_mutex_lock(pthread_mutex_t *mutex)
{
    AcquireSRWLockExclusive(mutex);
    return 0;
}

static int pthread_mutex_unlock(pthread_mutex_t *mutex)
{
    ReleaseSRWLockExclusive(mutex);
    return 0;
}

static int pthread_cond_init(pthread_cond_t *cond, void *unused_attr)
{
    (void)unused_attr;
    InitializeConditionVariable(cond);
    return 0;
}

static int pthread_cond_signal(pthread_cond_t *cond)
{
    WakeConditionVariable(cond);
    return 0;
}

static int pthread_cond_wait(pthread_cond_t *cond, pthread_mutex_t *mutex)
{
    return SleepConditionVariableSRW(cond, mutex, INFINITE, 0) ? 0 : EINVAL;
}

static int pthread_cond_timedwait(
    pthread_cond_t *cond,
    pthread_mutex_t *mutex,
    const struct timespec *abstime)
{
    FILETIME ft_now;
    ULARGE_INTEGER now;
    GetSystemTimeAsFileTime(&ft_now);
    now.LowPart = ft_now.dwLowDateTime;
    now.HighPart = ft_now.dwHighDateTime;

    uint64_t now_ns = (now.QuadPart - 116444736000000000ULL) * 100ULL;
    uint64_t target_ns =
        (uint64_t)abstime->tv_sec * 1000000000ULL + (uint64_t)abstime->tv_nsec;
    DWORD timeout_ms = 0;
    if (target_ns > now_ns)
    {
        uint64_t delta_ns = target_ns - now_ns;
        timeout_ms = (DWORD)((delta_ns + 999999ULL) / 1000000ULL);
    }

    if (SleepConditionVariableSRW(cond, mutex, timeout_ms, 0))
        return 0;
    return GetLastError() == ERROR_TIMEOUT ? ETIMEDOUT : EINVAL;
}

static int clock_gettime(int clk_id, struct timespec *ts)
{
    (void)clk_id;
    FILETIME ft_now;
    ULARGE_INTEGER now;
    GetSystemTimeAsFileTime(&ft_now);
    now.LowPart = ft_now.dwLowDateTime;
    now.HighPart = ft_now.dwHighDateTime;
    uint64_t ns = (now.QuadPart - 116444736000000000ULL) * 100ULL;
    ts->tv_sec = (time_t)(ns / 1000000000ULL);
    ts->tv_nsec = (long)(ns % 1000000000ULL);
    return 0;
}

static int nanosleep(const struct timespec *req, struct timespec *rem)
{
    (void)rem;
    DWORD ms = (DWORD)(req->tv_sec * 1000 + req->tv_nsec / 1000000L);
    if (ms == 0 && (req->tv_sec > 0 || req->tv_nsec > 0))
        ms = 1;
    Sleep(ms);
    return 0;
}

static int get_errno_code(void)
{
    int err = WSAGetLastError();
    switch (err)
    {
    case WSAEINTR:
        return EINTR;
    case WSAEWOULDBLOCK:
        return EWOULDBLOCK;
#ifdef WSAEAGAIN
    case WSAEAGAIN:
        return EAGAIN;
#endif
    default:
        return err;
    }
}

static int socket_last_error(void)
{
    return get_errno_code();
}

static int socket_would_block(int err)
{
    return err == EAGAIN || err == EWOULDBLOCK;
}

static int socket_interrupted(int err)
{
    return err == EINTR;
}

static void socket_close(socket_handle_t fd)
{
    if (fd != IPC_INVALID_SOCKET)
        closesocket(fd);
}

static void set_nonblocking(socket_handle_t fd)
{
    u_long mode = 1;
    ioctlsocket(fd, FIONBIO, &mode);
}

static int winsock_init(void)
{
    static int initialized = 0;
    static pthread_mutex_t init_mutex = PTHREAD_MUTEX_INITIALIZER;
    pthread_mutex_lock(&init_mutex);
    if (!initialized)
    {
        WSADATA wsa;
        if (WSAStartup(MAKEWORD(2, 2), &wsa) != 0)
        {
            pthread_mutex_unlock(&init_mutex);
            return -1;
        }
        initialized = 1;
    }
    pthread_mutex_unlock(&init_mutex);
    return 0;
}

#else
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/select.h>
#include <pthread.h>
#include <signal.h>
#include <fcntl.h>
#include <spawn.h>

typedef int socket_handle_t;

#define IPC_INVALID_SOCKET (-1)
#define UNUSED_ATTR __attribute__((unused))
static int socket_last_error(void)
{
    return errno;
}

static int socket_would_block(int err)
{
    return err == EAGAIN || err == EWOULDBLOCK;
}

static int socket_interrupted(int err)
{
    return err == EINTR;
}

static void socket_close(socket_handle_t fd)
{
    if (fd != IPC_INVALID_SOCKET)
        close(fd);
}

static void set_nonblocking(socket_handle_t fd)
{
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags >= 0)
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

static int winsock_init(void)
{
    return 0;
}
#endif

#ifdef __APPLE__
#include <dlfcn.h>
#endif

/* ── webview 前向声明 ─────────────────────────────────────────── */
typedef void *webview_t;
extern webview_t webview_create(int debug, void *window);
extern void webview_destroy(webview_t w);
extern void webview_run(webview_t w);
extern void webview_terminate(webview_t w);
extern void webview_dispatch(webview_t w, void (*f)(webview_t, void *), void *arg);
extern void webview_set_title(webview_t w, const char *title);
extern void webview_set_size(webview_t w, int width, int height, int hints);
extern void webview_navigate(webview_t w, const char *url);
extern void webview_init(webview_t w, const char *js);
extern int webview_eval(webview_t w, const char *js);
extern void webview_bind(webview_t w, const char *name,
                         void (*f)(const char *seq, const char *req, void *arg), void *arg);
extern void webview_unbind(webview_t w, const char *name);
extern void webview_return(webview_t w, const char *seq, int status, const char *result);
extern void webview_set_html(webview_t w, const char *html);
extern int64_t webview_get_window(webview_t w);
extern int64_t webview_get_native_handle(webview_t w, int kind);
#ifndef _WIN32
extern char **environ;
#endif

/* moonbit 运行时接口 */
#include "moonbit.h"

#endif /* LEPUS_WEBVIEW_C_ABI_H */
