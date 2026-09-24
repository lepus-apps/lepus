#include "../common/c_abi.h"

/*
 * This translation unit backs the `lepus-apps/lepus/webview/ffi/webview_sys`
 * package: the raw `webview.h` C binding glue (bind/unbind, background thread,
 * string copy, return and terminate). It is deliberately decoupled from the
 * window-manager runtime (`g_wm`) so the two FFI packages stay independent.
 */

/* MoonBit passes closures as (trampoline FuncRef, closure data) pairs.
 * webview_bind expects a plain C callback with a single void* user-data arg.
 * This struct bundles both so the trampoline can reconstruct the call. */
typedef void (*moonbit_webview_bind_callback_t)(void *seq, void *req, void *arg);

typedef struct
{
    moonbit_webview_bind_callback_t callback;
    void *arg; /* owned MoonBit closure; must moonbit_decref on free */
} moonbit_webview_binding;

/* webview_bind 回调蹦床：将 C 回调适配为 MoonBit closure 调用 */
static void moonbit_webview_bind_trampoline(
    const char *seq,
    const char *req,
    void *arg)
{
    moonbit_webview_binding *binding = (moonbit_webview_binding *)arg;
    if (!binding || !binding->callback)
        return;

    /* Pass raw C string pointers. The MoonBit side copies via
     * webview_copy_cstr inside the bind callback. */
    binding->callback((void *)seq, (void *)req, binding->arg);
}

/*
 * 将 MoonBit closure 绑定到指定 JS 函数名。
 * 返回 binding 指针（不透明句柄），供 moonbit_webview_unbind 使用。
 */
MOONBIT_FFI_EXPORT void *moonbit_webview_bind(
    webview_t w,
    const char *name,
    moonbit_webview_bind_callback_t fn,
    void *arg /* #owned: MoonBit transferred ownership to C side */)
{
    moonbit_webview_binding *binding =
        (moonbit_webview_binding *)malloc(sizeof(moonbit_webview_binding));
    if (!binding)
    {
        if (arg)
            moonbit_decref(arg);
        return NULL;
    }

    binding->callback = fn;
    binding->arg = arg;

    webview_bind(w, name, moonbit_webview_bind_trampoline, binding);
    return binding;
}

/*
 * 解绑 JS 函数并释放 binding 结构。
 */
MOONBIT_FFI_EXPORT void moonbit_webview_unbind(
    webview_t w,
    const char *name,
    void *binding_ptr)
{
    webview_unbind(w, name);
    if (binding_ptr)
    {
        moonbit_webview_binding *binding = (moonbit_webview_binding *)binding_ptr;
        if (binding->arg)
            moonbit_decref(binding->arg);
        free(binding);
    }
}

typedef void (*moonbit_thread_closure_t)(void *arg);

typedef struct
{
    moonbit_thread_closure_t callback;
    void *arg;
} moonbit_thread_task_t;

static void *moonbit_background_thread_main(void *arg)
{
    moonbit_thread_task_t *task = (moonbit_thread_task_t *)arg;
    task->callback(task->arg);
    if (task->arg)
        moonbit_decref(task->arg);
    free(task);
    return NULL;
}

MOONBIT_FFI_EXPORT int moonbit_run_in_background_thread(
    moonbit_thread_closure_t fn,
    void *arg)
{
    moonbit_thread_task_t *task =
        (moonbit_thread_task_t *)malloc(sizeof(moonbit_thread_task_t));
    if (!task)
    {
        if (arg)
            moonbit_decref(arg);
        return -1;
    }
    task->callback = fn;
    task->arg = arg;

    pthread_t thread;
    if (pthread_create(&thread, NULL, moonbit_background_thread_main, task) != 0)
    {
        if (arg)
            moonbit_decref(arg);
        free(task);
        return -1;
    }
    pthread_detach(thread);
    return 0;
}

/* Thin wrapper around webview_return for MoonBit FFI. */
MOONBIT_FFI_EXPORT void moonbit_webview_return_raw(
    webview_t w,
    const char *seq,
    int status,
    const char *result)
{
    webview_return(w, seq, status, result);
}

/* Thin wrapper around webview_terminate for MoonBit FFI. */
MOONBIT_FFI_EXPORT void moonbit_webview_terminate(webview_t w)
{
    webview_terminate(w);
}

/*
 * Copy a null-terminated C string into a MoonBit Bytes value. The copy is
 * unavoidable: seq/req pointers from webview are only valid for the duration of
 * the C callback, so we copy them into GC-managed Bytes for the closure.
 */
MOONBIT_FFI_EXPORT moonbit_bytes_t moonbit_webview_copy_cstr(const char *cstr)
{
    if (cstr == NULL)
        return moonbit_make_bytes_raw(0);
    size_t len = strlen(cstr);
    if (len > INT32_MAX)
        abort();
    moonbit_bytes_t bytes = moonbit_make_bytes_raw((int32_t)len);
    memcpy(bytes, cstr, len);
    return bytes;
}