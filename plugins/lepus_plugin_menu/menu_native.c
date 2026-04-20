#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "moonbit.h"

#if defined(__APPLE__)
#include <dlfcn.h>
#endif

static char g_menu_last_error[512] = "";

static void lp_menu_set_error(const char *message) {
  if (!message) {
    g_menu_last_error[0] = '\0';
    return;
  }
  snprintf(g_menu_last_error, sizeof(g_menu_last_error), "%s", message);
}

static moonbit_bytes_t lp_menu_bytes(const char *text) {
  int32_t len = (int32_t)strlen(text ? text : "");
  moonbit_bytes_t out = moonbit_make_bytes(len, 0);
  if (len > 0) {
    memcpy(out, text, (size_t)len);
  }
  return out;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t lp_menu_last_error_message(void) {
  return lp_menu_bytes(g_menu_last_error);
}

MOONBIT_FFI_EXPORT int32_t lp_menu_supported(void) {
#if defined(__APPLE__)
  return 1;
#else
  return 0;
#endif
}

#if defined(__APPLE__)

typedef void *mb_id_t;
typedef void *mb_sel_t;
typedef mb_sel_t (*mb_sel_register_name_t)(const char *);
typedef mb_id_t (*mb_objc_get_class_t)(const char *);
typedef mb_id_t (*mb_objc_msgsend_id_ret_t)(mb_id_t, mb_sel_t);
typedef mb_id_t (*mb_objc_msgsend_cstr_arg_ret_t)(mb_id_t, mb_sel_t, const char *);
typedef mb_id_t (*mb_objc_msgsend_id_sel_id_arg_ret_t)(mb_id_t, mb_sel_t, mb_id_t, mb_sel_t, mb_id_t);
typedef mb_id_t (*mb_objc_msgsend_u64_arg_ret_t)(mb_id_t, mb_sel_t, unsigned long);
typedef unsigned long (*mb_objc_msgsend_u64_ret_t)(mb_id_t, mb_sel_t);
typedef int (*mb_objc_msgsend_id_arg_int_ret_t)(mb_id_t, mb_sel_t, mb_id_t);
typedef void (*mb_objc_msgsend_id_arg_t)(mb_id_t, mb_sel_t, mb_id_t);
typedef void (*mb_objc_msgsend_id_id_arg_t)(mb_id_t, mb_sel_t, mb_id_t, mb_id_t);
typedef void (*mb_objc_msgsend_id_long_arg_t)(mb_id_t, mb_sel_t, mb_id_t, long);
typedef void (*mb_objc_msgsend_int_arg_t)(mb_id_t, mb_sel_t, int);
typedef void (*mb_objc_msgsend_u64_arg_t)(mb_id_t, mb_sel_t, unsigned long);
typedef const char *(*mb_objc_msgsend_cstr_ret_t)(mb_id_t, mb_sel_t);
typedef int (*mb_class_add_method_t)(mb_id_t, mb_sel_t, void *, const char *);
typedef mb_id_t (*mb_objc_allocate_class_pair_t)(mb_id_t, const char *, size_t);
typedef void (*mb_objc_register_class_pair_t)(mb_id_t);

typedef enum {
  LP_MENU_ENTRY_NONE = 0,
  LP_MENU_ENTRY_MENU = 1,
  LP_MENU_ENTRY_ITEM = 2,
  LP_MENU_ENTRY_SUBMENU = 3,
  LP_MENU_ENTRY_CHECK_ITEM = 4,
  LP_MENU_ENTRY_PREDEFINED = 5
} lp_menu_entry_type_t;

typedef struct {
  int used;
  char *id;
  lp_menu_entry_type_t type;
  mb_id_t object;
  mb_id_t aux_object;
  mb_id_t parent_menu;
} lp_menu_entry_t;

typedef struct {
  void *msgsend;
  mb_sel_register_name_t sel_register_name;
  mb_objc_get_class_t objc_get_class;
  mb_class_add_method_t class_add_method;
  mb_objc_allocate_class_pair_t objc_allocate_class_pair;
  mb_objc_register_class_pair_t objc_register_class_pair;
} lp_objc_api_t;

static lp_objc_api_t g_objc = {0};
static int g_objc_loaded = 0;

#define LP_MENU_MAX_ENTRIES 1024
#define LP_MENU_MAX_EVENTS 2048
static lp_menu_entry_t g_menu_entries[LP_MENU_MAX_ENTRIES];
static char *g_menu_events[LP_MENU_MAX_EVENTS];
static int g_menu_event_count = 0;
static mb_id_t g_menu_action_target = NULL;
static int g_menu_target_installed = 0;

static char *lp_strdup(const char *text) {
  size_t len = strlen(text ? text : "");
  char *copy = (char *)malloc(len + 1);
  if (!copy) return NULL;
  if (len > 0) memcpy(copy, text, len);
  copy[len] = '\0';
  return copy;
}

static int lp_string_eq(const char *left, const char *right) {
  if (!left || !right) return 0;
  return strcmp(left, right) == 0;
}

static void lp_trim(char *text) {
  if (!text) return;
  size_t len = strlen(text);
  size_t start = 0;
  while (start < len && isspace((unsigned char)text[start])) start++;
  size_t end = len;
  while (end > start && isspace((unsigned char)text[end - 1])) end--;
  if (start > 0) memmove(text, text + start, end - start);
  text[end - start] = '\0';
}

static void lp_lower_ascii(char *text) {
  if (!text) return;
  for (size_t i = 0; text[i] != '\0'; i++) {
    text[i] = (char)tolower((unsigned char)text[i]);
  }
}

static int lp_objc_load(void) {
  if (g_objc_loaded) return g_objc.msgsend != NULL;
  g_objc_loaded = 1;

  void *lib = dlopen("/usr/lib/libobjc.A.dylib", RTLD_LAZY);
  if (!lib) lib = dlopen("/usr/lib/libobjc.dylib", RTLD_LAZY);
  if (!lib) return 0;

  g_objc.msgsend = dlsym(lib, "objc_msgSend");
  g_objc.sel_register_name = (mb_sel_register_name_t)dlsym(lib, "sel_registerName");
  g_objc.objc_get_class = (mb_objc_get_class_t)dlsym(lib, "objc_getClass");
  g_objc.class_add_method = (mb_class_add_method_t)dlsym(lib, "class_addMethod");
  g_objc.objc_allocate_class_pair =
      (mb_objc_allocate_class_pair_t)dlsym(lib, "objc_allocateClassPair");
  g_objc.objc_register_class_pair =
      (mb_objc_register_class_pair_t)dlsym(lib, "objc_registerClassPair");
  return g_objc.msgsend && g_objc.sel_register_name && g_objc.objc_get_class;
}

static mb_sel_t lp_sel(const char *name) {
  return lp_objc_load() ? g_objc.sel_register_name(name) : NULL;
}

static mb_id_t lp_cls(const char *name) {
  return lp_objc_load() ? g_objc.objc_get_class(name) : NULL;
}

static mb_id_t lp_nsstring(const char *text) {
  if (!lp_objc_load()) return NULL;
  mb_id_t ns_string = lp_cls("NSString");
  mb_sel_t sel_string_with_utf8 = lp_sel("stringWithUTF8String:");
  if (!ns_string || !sel_string_with_utf8) return NULL;
  return ((mb_objc_msgsend_cstr_arg_ret_t)g_objc.msgsend)(
      ns_string, sel_string_with_utf8, text ? text : "");
}

static mb_id_t lp_menu_for_entry(lp_menu_entry_t *entry) {
  if (!entry) return NULL;
  if (entry->type == LP_MENU_ENTRY_MENU) return entry->object;
  if (entry->type == LP_MENU_ENTRY_SUBMENU) return entry->aux_object;
  return NULL;
}

static mb_id_t lp_item_for_entry(lp_menu_entry_t *entry) {
  if (!entry) return NULL;
  if (entry->type == LP_MENU_ENTRY_MENU) return NULL;
  return entry->object;
}

static lp_menu_entry_t *lp_find_entry(const char *id) {
  if (!id || id[0] == '\0') return NULL;
  for (int i = 0; i < LP_MENU_MAX_ENTRIES; i++) {
    if (g_menu_entries[i].used && lp_string_eq(g_menu_entries[i].id, id)) {
      return &g_menu_entries[i];
    }
  }
  return NULL;
}

static lp_menu_entry_t *lp_alloc_entry(const char *id) {
  if (!id || id[0] == '\0') {
    lp_menu_set_error("menu id is empty");
    return NULL;
  }
  if (lp_find_entry(id)) {
    lp_menu_set_error("menu id already exists");
    return NULL;
  }
  for (int i = 0; i < LP_MENU_MAX_ENTRIES; i++) {
    if (!g_menu_entries[i].used) {
      g_menu_entries[i].used = 1;
      g_menu_entries[i].id = lp_strdup(id);
      g_menu_entries[i].type = LP_MENU_ENTRY_NONE;
      g_menu_entries[i].object = NULL;
      g_menu_entries[i].aux_object = NULL;
      g_menu_entries[i].parent_menu = NULL;
      if (!g_menu_entries[i].id) {
        g_menu_entries[i].used = 0;
        lp_menu_set_error("out of memory");
        return NULL;
      }
      return &g_menu_entries[i];
    }
  }
  lp_menu_set_error("menu registry is full");
  return NULL;
}

static void lp_free_events(void) {
  for (int i = 0; i < g_menu_event_count; i++) {
    free(g_menu_events[i]);
    g_menu_events[i] = NULL;
  }
  g_menu_event_count = 0;
}

static void lp_event_push(const char *id) {
  if (!id || id[0] == '\0') return;
  if (g_menu_event_count >= LP_MENU_MAX_EVENTS) return;
  g_menu_events[g_menu_event_count++] = lp_strdup(id);
}

static void lp_clear_entries(void) {
  for (int i = 0; i < LP_MENU_MAX_ENTRIES; i++) {
    if (!g_menu_entries[i].used) continue;
    free(g_menu_entries[i].id);
    g_menu_entries[i].id = NULL;
    g_menu_entries[i].used = 0;
    g_menu_entries[i].type = LP_MENU_ENTRY_NONE;
    g_menu_entries[i].object = NULL;
    g_menu_entries[i].aux_object = NULL;
    g_menu_entries[i].parent_menu = NULL;
  }
  lp_free_events();
}

static int lp_accelerator_parse(const char *accelerator, char *key_buf, size_t key_buf_size,
                                unsigned long *mods) {
  if (!key_buf || key_buf_size < 2 || !mods) return 0;
  key_buf[0] = '\0';
  *mods = 0;
  if (!accelerator || accelerator[0] == '\0') return 1;

  char *copy = lp_strdup(accelerator);
  if (!copy) return 0;

  const unsigned long NSEventModifierFlagCapsLock = 1UL << 16;
  const unsigned long NSEventModifierFlagShift = 1UL << 17;
  const unsigned long NSEventModifierFlagControl = 1UL << 18;
  const unsigned long NSEventModifierFlagOption = 1UL << 19;
  const unsigned long NSEventModifierFlagCommand = 1UL << 20;
  (void)NSEventModifierFlagCapsLock;

  char *token = strtok(copy, "+");
  char key_candidate[32] = "";
  while (token) {
    lp_trim(token);
    lp_lower_ascii(token);
    if (lp_string_eq(token, "cmd") || lp_string_eq(token, "command") ||
        lp_string_eq(token, "cmdorctrl") || lp_string_eq(token, "super") ||
        lp_string_eq(token, "meta")) {
      *mods |= NSEventModifierFlagCommand;
    } else if (lp_string_eq(token, "ctrl") || lp_string_eq(token, "control")) {
      *mods |= NSEventModifierFlagControl;
    } else if (lp_string_eq(token, "alt") || lp_string_eq(token, "option")) {
      *mods |= NSEventModifierFlagOption;
    } else if (lp_string_eq(token, "shift")) {
      *mods |= NSEventModifierFlagShift;
    } else {
      snprintf(key_candidate, sizeof(key_candidate), "%s", token);
    }
    token = strtok(NULL, "+");
  }

  if (key_candidate[0] == '\0') {
    free(copy);
    return 1;
  }
  if (strlen(key_candidate) == 1) {
    key_buf[0] = key_candidate[0];
    key_buf[1] = '\0';
    free(copy);
    return 1;
  }
  if (lp_string_eq(key_candidate, "space")) {
    snprintf(key_buf, key_buf_size, " ");
  } else if (lp_string_eq(key_candidate, "plus")) {
    snprintf(key_buf, key_buf_size, "+");
  } else if (lp_string_eq(key_candidate, "tab")) {
    snprintf(key_buf, key_buf_size, "\t");
  } else if (lp_string_eq(key_candidate, "enter") || lp_string_eq(key_candidate, "return")) {
    snprintf(key_buf, key_buf_size, "\r");
  } else if (lp_string_eq(key_candidate, "esc") || lp_string_eq(key_candidate, "escape")) {
    snprintf(key_buf, key_buf_size, "\033");
  } else if (lp_string_eq(key_candidate, "delete") || lp_string_eq(key_candidate, "backspace")) {
    snprintf(key_buf, key_buf_size, "\177");
  } else {
    snprintf(key_buf, key_buf_size, "%s", key_candidate);
  }

  free(copy);
  return 1;
}

static int lp_apply_accelerator(mb_id_t item, const char *accelerator) {
  mb_sel_t sel_set_key = lp_sel("setKeyEquivalent:");
  mb_sel_t sel_set_mask = lp_sel("setKeyEquivalentModifierMask:");
  if (!sel_set_key || !sel_set_mask) return 0;

  char key[32] = "";
  unsigned long mods = 0;
  if (!lp_accelerator_parse(accelerator, key, sizeof(key), &mods)) return 0;
  mb_id_t ns_key = lp_nsstring(key);
  if (!ns_key) return 0;
  ((mb_objc_msgsend_id_arg_t)g_objc.msgsend)(item, sel_set_key, ns_key);
  ((mb_objc_msgsend_u64_arg_t)g_objc.msgsend)(item, sel_set_mask, mods);
  return 1;
}

static lp_menu_entry_t *lp_find_entry_for_item_id(const char *id) {
  lp_menu_entry_t *entry = lp_find_entry(id);
  return entry;
}

static void lp_menu_item_triggered(mb_id_t self, mb_sel_t cmd, mb_id_t sender) {
  (void)self;
  (void)cmd;
  if (!lp_objc_load() || !sender) return;
  mb_sel_t sel_represented_object = lp_sel("representedObject");
  mb_sel_t sel_utf8 = lp_sel("UTF8String");
  if (!sel_represented_object || !sel_utf8) return;
  mb_id_t represented = ((mb_objc_msgsend_id_ret_t)g_objc.msgsend)(sender, sel_represented_object);
  if (!represented) return;
  const char *menu_id = ((mb_objc_msgsend_cstr_ret_t)g_objc.msgsend)(represented, sel_utf8);
  if (!menu_id || menu_id[0] == '\0') return;
  lp_event_push(menu_id);

  lp_menu_entry_t *entry = lp_find_entry_for_item_id(menu_id);
  if (entry && entry->type == LP_MENU_ENTRY_CHECK_ITEM) {
    mb_sel_t sel_state = lp_sel("state");
    mb_sel_t sel_set_state = lp_sel("setState:");
    if (sel_state && sel_set_state) {
      unsigned long current = ((mb_objc_msgsend_u64_ret_t)g_objc.msgsend)(sender, sel_state);
      ((mb_objc_msgsend_u64_arg_t)g_objc.msgsend)(sender, sel_set_state, current ? 0UL : 1UL);
    }
  }
}

static int lp_install_action_target(void) {
  if (g_menu_target_installed && g_menu_action_target) return 1;
  if (!lp_objc_load() || !g_objc.class_add_method || !g_objc.objc_allocate_class_pair ||
      !g_objc.objc_register_class_pair) {
    return 0;
  }
  mb_id_t ns_object = lp_cls("NSObject");
  if (!ns_object) return 0;

  mb_id_t cls = lp_cls("LPMenuActionTarget");
  if (!cls) {
    cls = g_objc.objc_allocate_class_pair(ns_object, "LPMenuActionTarget", 0);
    if (!cls) return 0;
    mb_sel_t sel_action = lp_sel("lpMenuItemTriggered:");
    if (!sel_action) return 0;
    if (!g_objc.class_add_method(cls, sel_action, (void *)&lp_menu_item_triggered, "v@:@")) {
      return 0;
    }
    g_objc.objc_register_class_pair(cls);
  }

  mb_sel_t sel_alloc = lp_sel("alloc");
  mb_sel_t sel_init = lp_sel("init");
  if (!sel_alloc || !sel_init) return 0;
  mb_id_t instance = ((mb_objc_msgsend_id_ret_t)g_objc.msgsend)(cls, sel_alloc);
  if (!instance) return 0;
  instance = ((mb_objc_msgsend_id_ret_t)g_objc.msgsend)(instance, sel_init);
  if (!instance) return 0;
  g_menu_action_target = instance;
  g_menu_target_installed = 1;
  return 1;
}

static mb_id_t lp_new_menu(void) {
  mb_id_t ns_menu_cls = lp_cls("NSMenu");
  mb_sel_t sel_alloc = lp_sel("alloc");
  mb_sel_t sel_init = lp_sel("init");
  if (!ns_menu_cls || !sel_alloc || !sel_init) return NULL;
  mb_id_t menu = ((mb_objc_msgsend_id_ret_t)g_objc.msgsend)(ns_menu_cls, sel_alloc);
  if (!menu) return NULL;
  return ((mb_objc_msgsend_id_ret_t)g_objc.msgsend)(menu, sel_init);
}

static mb_id_t lp_new_menu_item(const char *title, const char *action_name, const char *key) {
  mb_id_t ns_menu_item_cls = lp_cls("NSMenuItem");
  mb_sel_t sel_alloc = lp_sel("alloc");
  mb_sel_t sel_init = lp_sel("initWithTitle:action:keyEquivalent:");
  if (!ns_menu_item_cls || !sel_alloc || !sel_init) return NULL;
  mb_id_t item = ((mb_objc_msgsend_id_ret_t)g_objc.msgsend)(ns_menu_item_cls, sel_alloc);
  if (!item) return NULL;
  mb_id_t ns_title = lp_nsstring(title ? title : "");
  mb_id_t ns_key = lp_nsstring(key ? key : "");
  mb_sel_t action = action_name ? lp_sel(action_name) : NULL;
  if (!ns_title || !ns_key) return NULL;
  return ((mb_objc_msgsend_id_sel_id_arg_ret_t)g_objc.msgsend)(item, sel_init, ns_title, action,
                                                                ns_key);
}

static int lp_mark_item_with_id(mb_id_t item, const char *id) {
  mb_sel_t sel_set_represented_object = lp_sel("setRepresentedObject:");
  if (!sel_set_represented_object) return 0;
  mb_id_t ns_id = lp_nsstring(id);
  if (!ns_id) return 0;
  ((mb_objc_msgsend_id_arg_t)g_objc.msgsend)(item, sel_set_represented_object, ns_id);
  return 1;
}

static int lp_set_item_target_action(mb_id_t item) {
  if (!lp_install_action_target()) return 0;
  mb_sel_t sel_set_target = lp_sel("setTarget:");
  mb_sel_t sel_set_action = lp_sel("setAction:");
  if (!sel_set_target || !sel_set_action) return 0;
  ((mb_objc_msgsend_id_arg_t)g_objc.msgsend)(item, sel_set_target, g_menu_action_target);
  ((mb_objc_msgsend_id_arg_t)g_objc.msgsend)(item, sel_set_action,
                                             (mb_id_t)lp_sel("lpMenuItemTriggered:"));
  return 1;
}

static int lp_set_item_enabled(mb_id_t item, int enabled) {
  mb_sel_t sel_set_enabled = lp_sel("setEnabled:");
  if (!sel_set_enabled) return 0;
  ((mb_objc_msgsend_int_arg_t)g_objc.msgsend)(item, sel_set_enabled, enabled ? 1 : 0);
  return 1;
}

static int lp_set_item_state(mb_id_t item, int checked) {
  mb_sel_t sel_set_state = lp_sel("setState:");
  if (!sel_set_state) return 0;
  ((mb_objc_msgsend_u64_arg_t)g_objc.msgsend)(item, sel_set_state, checked ? 1UL : 0UL);
  return 1;
}

static mb_id_t lp_create_predefined_item_object(const char *kind, const char *text) {
  char key[32] = "";
  unsigned long mods = 0;
  const char *title = text;
  const char *action = NULL;

  if (!kind) return NULL;
  if (lp_string_eq(kind, "separator")) {
    mb_id_t cls = lp_cls("NSMenuItem");
    mb_sel_t sel_separator = lp_sel("separatorItem");
    if (!cls || !sel_separator) return NULL;
    return ((mb_objc_msgsend_id_ret_t)g_objc.msgsend)(cls, sel_separator);
  }

  if (lp_string_eq(kind, "copy")) {
    title = text && text[0] ? text : "Copy";
    action = "copy:";
    snprintf(key, sizeof(key), "c");
    mods = 1UL << 20;
  } else if (lp_string_eq(kind, "cut")) {
    title = text && text[0] ? text : "Cut";
    action = "cut:";
    snprintf(key, sizeof(key), "x");
    mods = 1UL << 20;
  } else if (lp_string_eq(kind, "paste")) {
    title = text && text[0] ? text : "Paste";
    action = "paste:";
    snprintf(key, sizeof(key), "v");
    mods = 1UL << 20;
  } else if (lp_string_eq(kind, "select_all")) {
    title = text && text[0] ? text : "Select All";
    action = "selectAll:";
    snprintf(key, sizeof(key), "a");
    mods = 1UL << 20;
  } else if (lp_string_eq(kind, "undo")) {
    title = text && text[0] ? text : "Undo";
    action = "undo:";
    snprintf(key, sizeof(key), "z");
    mods = 1UL << 20;
  } else if (lp_string_eq(kind, "redo")) {
    title = text && text[0] ? text : "Redo";
    action = "redo:";
    snprintf(key, sizeof(key), "Z");
    mods = (1UL << 20) | (1UL << 17);
  } else if (lp_string_eq(kind, "minimize")) {
    title = text && text[0] ? text : "Minimize";
    action = "performMiniaturize:";
    snprintf(key, sizeof(key), "m");
    mods = 1UL << 20;
  } else if (lp_string_eq(kind, "zoom")) {
    title = text && text[0] ? text : "Zoom";
    action = "performZoom:";
  } else if (lp_string_eq(kind, "fullscreen")) {
    title = text && text[0] ? text : "Enter Full Screen";
    action = "toggleFullScreen:";
    snprintf(key, sizeof(key), "f");
    mods = (1UL << 20) | (1UL << 18);
  } else if (lp_string_eq(kind, "hide")) {
    title = text && text[0] ? text : "Hide";
    action = "hide:";
    snprintf(key, sizeof(key), "h");
    mods = 1UL << 20;
  } else if (lp_string_eq(kind, "hide_others")) {
    title = text && text[0] ? text : "Hide Others";
    action = "hideOtherApplications:";
    snprintf(key, sizeof(key), "h");
    mods = (1UL << 20) | (1UL << 19);
  } else if (lp_string_eq(kind, "show_all")) {
    title = text && text[0] ? text : "Show All";
    action = "unhideAllApplications:";
  } else if (lp_string_eq(kind, "about")) {
    title = text && text[0] ? text : "About";
    action = "orderFrontStandardAboutPanel:";
  } else if (lp_string_eq(kind, "quit")) {
    title = text && text[0] ? text : "Quit";
    action = "terminate:";
    snprintf(key, sizeof(key), "q");
    mods = 1UL << 20;
  } else {
    lp_menu_set_error("unsupported predefined menu item kind");
    return NULL;
  }

  mb_id_t item = lp_new_menu_item(title ? title : "", action, key);
  if (!item) return NULL;
  if (mods != 0) {
    mb_sel_t sel_set_mask = lp_sel("setKeyEquivalentModifierMask:");
    if (sel_set_mask) ((mb_objc_msgsend_u64_arg_t)g_objc.msgsend)(item, sel_set_mask, mods);
  }
  return item;
}

static int lp_delete_entry_internal(lp_menu_entry_t *entry) {
  if (!entry || !entry->used) return 0;

  if (entry->parent_menu && entry->object) {
    mb_sel_t sel_remove = lp_sel("removeItem:");
    if (sel_remove) {
      ((mb_objc_msgsend_id_arg_t)g_objc.msgsend)(entry->parent_menu, sel_remove, entry->object);
    }
  }

  free(entry->id);
  entry->id = NULL;
  entry->used = 0;
  entry->type = LP_MENU_ENTRY_NONE;
  entry->object = NULL;
  entry->aux_object = NULL;
  entry->parent_menu = NULL;
  return 1;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_clear_app_menu(void) {
  lp_menu_set_error(NULL);
  if (!lp_objc_load()) {
    lp_menu_set_error("objc runtime unavailable");
    return 1;
  }
  mb_id_t ns_app = lp_cls("NSApplication");
  mb_sel_t sel_shared = lp_sel("sharedApplication");
  mb_sel_t sel_set_main = lp_sel("setMainMenu:");
  if (!ns_app || !sel_shared || !sel_set_main) {
    lp_menu_set_error("NSApplication API unavailable");
    return 1;
  }
  mb_id_t app = ((mb_objc_msgsend_id_ret_t)g_objc.msgsend)(ns_app, sel_shared);
  if (!app) {
    lp_menu_set_error("NSApplication shared instance unavailable");
    return 1;
  }
  ((mb_objc_msgsend_id_arg_t)g_objc.msgsend)(app, sel_set_main, NULL);
  return 0;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_reset(void) {
  lp_menu_set_error(NULL);
  if (!lp_objc_load()) {
    lp_menu_set_error("objc runtime unavailable");
    return 1;
  }
  lp_menu_clear_app_menu();
  lp_clear_entries();
  return 0;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_create_menu(const char *id) {
  lp_menu_set_error(NULL);
  if (!lp_objc_load()) {
    lp_menu_set_error("objc runtime unavailable");
    return 1;
  }
  lp_menu_entry_t *entry = lp_alloc_entry(id);
  if (!entry) return 1;
  entry->object = lp_new_menu();
  if (!entry->object) {
    lp_delete_entry_internal(entry);
    lp_menu_set_error("create NSMenu failed");
    return 1;
  }
  entry->type = LP_MENU_ENTRY_MENU;
  return 0;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_create_submenu(const char *id, const char *title,
                                                  int32_t enabled) {
  lp_menu_set_error(NULL);
  if (!lp_objc_load()) {
    lp_menu_set_error("objc runtime unavailable");
    return 1;
  }
  lp_menu_entry_t *entry = lp_alloc_entry(id);
  if (!entry) return 1;

  mb_id_t item = lp_new_menu_item(title ? title : "", NULL, "");
  mb_id_t submenu = lp_new_menu();
  if (!item || !submenu) {
    lp_delete_entry_internal(entry);
    lp_menu_set_error("create submenu failed");
    return 1;
  }
  mb_sel_t sel_set_submenu = lp_sel("setSubmenu:");
  if (!sel_set_submenu) {
    lp_delete_entry_internal(entry);
    lp_menu_set_error("setSubmenu selector unavailable");
    return 1;
  }
  ((mb_objc_msgsend_id_arg_t)g_objc.msgsend)(item, sel_set_submenu, submenu);
  lp_set_item_enabled(item, enabled ? 1 : 0);
  entry->type = LP_MENU_ENTRY_SUBMENU;
  entry->object = item;
  entry->aux_object = submenu;
  return 0;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_create_item(const char *id, const char *text, int32_t enabled,
                                               const char *accelerator) {
  lp_menu_set_error(NULL);
  if (!lp_objc_load()) {
    lp_menu_set_error("objc runtime unavailable");
    return 1;
  }
  lp_menu_entry_t *entry = lp_alloc_entry(id);
  if (!entry) return 1;

  mb_id_t item = lp_new_menu_item(text ? text : "", NULL, "");
  if (!item) {
    lp_delete_entry_internal(entry);
    lp_menu_set_error("create menu item failed");
    return 1;
  }
  if (!lp_mark_item_with_id(item, id) || !lp_set_item_target_action(item)) {
    lp_delete_entry_internal(entry);
    lp_menu_set_error("configure menu item target failed");
    return 1;
  }
  lp_set_item_enabled(item, enabled ? 1 : 0);
  if (accelerator && accelerator[0]) {
    if (!lp_apply_accelerator(item, accelerator)) {
      lp_delete_entry_internal(entry);
      lp_menu_set_error("invalid accelerator");
      return 1;
    }
  }
  entry->type = LP_MENU_ENTRY_ITEM;
  entry->object = item;
  return 0;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_create_check_item(const char *id, const char *text,
                                                     int32_t enabled, int32_t checked,
                                                     const char *accelerator) {
  lp_menu_set_error(NULL);
  if (lp_menu_create_item(id, text, enabled, accelerator) != 0) return 1;
  lp_menu_entry_t *entry = lp_find_entry(id);
  if (!entry || !entry->object) {
    lp_menu_set_error("create check menu item failed");
    return 1;
  }
  entry->type = LP_MENU_ENTRY_CHECK_ITEM;
  if (!lp_set_item_state(entry->object, checked ? 1 : 0)) {
    lp_menu_set_error("set check menu state failed");
    return 1;
  }
  return 0;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_create_predefined_item(const char *id, const char *kind,
                                                          const char *text) {
  lp_menu_set_error(NULL);
  if (!lp_objc_load()) {
    lp_menu_set_error("objc runtime unavailable");
    return 1;
  }
  lp_menu_entry_t *entry = lp_alloc_entry(id);
  if (!entry) return 1;

  char *kind_copy = lp_strdup(kind ? kind : "");
  if (!kind_copy) {
    lp_delete_entry_internal(entry);
    lp_menu_set_error("out of memory");
    return 1;
  }
  lp_trim(kind_copy);
  lp_lower_ascii(kind_copy);
  mb_id_t item = lp_create_predefined_item_object(kind_copy, text ? text : "");
  free(kind_copy);
  if (!item) {
    lp_delete_entry_internal(entry);
    if (g_menu_last_error[0] == '\0') lp_menu_set_error("create predefined item failed");
    return 1;
  }
  entry->type = LP_MENU_ENTRY_PREDEFINED;
  entry->object = item;
  return 0;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_append(const char *parent_id, const char *child_id) {
  lp_menu_set_error(NULL);
  lp_menu_entry_t *parent = lp_find_entry(parent_id);
  lp_menu_entry_t *child = lp_find_entry(child_id);
  if (!parent || !child) {
    lp_menu_set_error("menu id not found");
    return 1;
  }
  mb_id_t parent_menu = lp_menu_for_entry(parent);
  mb_id_t child_item = lp_item_for_entry(child);
  if (!parent_menu || !child_item) {
    lp_menu_set_error("invalid parent or child entry");
    return 1;
  }
  mb_sel_t sel_add = lp_sel("addItem:");
  if (!sel_add) {
    lp_menu_set_error("addItem selector unavailable");
    return 1;
  }
  ((mb_objc_msgsend_id_arg_t)g_objc.msgsend)(parent_menu, sel_add, child_item);
  child->parent_menu = parent_menu;
  return 0;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_insert(const char *parent_id, const char *child_id,
                                          int32_t position) {
  lp_menu_set_error(NULL);
  lp_menu_entry_t *parent = lp_find_entry(parent_id);
  lp_menu_entry_t *child = lp_find_entry(child_id);
  if (!parent || !child) {
    lp_menu_set_error("menu id not found");
    return 1;
  }
  mb_id_t parent_menu = lp_menu_for_entry(parent);
  mb_id_t child_item = lp_item_for_entry(child);
  if (!parent_menu || !child_item) {
    lp_menu_set_error("invalid parent or child entry");
    return 1;
  }
  mb_sel_t sel_insert = lp_sel("insertItem:atIndex:");
  if (!sel_insert) {
    lp_menu_set_error("insertItem selector unavailable");
    return 1;
  }
  ((mb_objc_msgsend_id_long_arg_t)g_objc.msgsend)(parent_menu, sel_insert, child_item,
                                                  (long)position);
  child->parent_menu = parent_menu;
  return 0;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_remove(const char *parent_id, const char *child_id) {
  lp_menu_set_error(NULL);
  lp_menu_entry_t *parent = lp_find_entry(parent_id);
  lp_menu_entry_t *child = lp_find_entry(child_id);
  if (!parent || !child) {
    lp_menu_set_error("menu id not found");
    return 1;
  }
  mb_id_t parent_menu = lp_menu_for_entry(parent);
  mb_id_t child_item = lp_item_for_entry(child);
  if (!parent_menu || !child_item) {
    lp_menu_set_error("invalid parent or child entry");
    return 1;
  }
  mb_sel_t sel_remove = lp_sel("removeItem:");
  if (!sel_remove) {
    lp_menu_set_error("removeItem selector unavailable");
    return 1;
  }
  ((mb_objc_msgsend_id_arg_t)g_objc.msgsend)(parent_menu, sel_remove, child_item);
  child->parent_menu = NULL;
  return 0;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_set_as_app_menu(const char *id) {
  lp_menu_set_error(NULL);
  lp_menu_entry_t *entry = lp_find_entry(id);
  if (!entry) {
    lp_menu_set_error("menu id not found");
    return 1;
  }
  mb_id_t menu = lp_menu_for_entry(entry);
  if (!menu) {
    lp_menu_set_error("entry is not a menu");
    return 1;
  }
  mb_id_t ns_app = lp_cls("NSApplication");
  mb_sel_t sel_shared = lp_sel("sharedApplication");
  mb_sel_t sel_set_main = lp_sel("setMainMenu:");
  if (!ns_app || !sel_shared || !sel_set_main) {
    lp_menu_set_error("NSApplication API unavailable");
    return 1;
  }
  mb_id_t app = ((mb_objc_msgsend_id_ret_t)g_objc.msgsend)(ns_app, sel_shared);
  if (!app) {
    lp_menu_set_error("NSApplication shared instance unavailable");
    return 1;
  }
  ((mb_objc_msgsend_id_arg_t)g_objc.msgsend)(app, sel_set_main, menu);
  return 0;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_set_enabled(const char *id, int32_t enabled) {
  lp_menu_set_error(NULL);
  lp_menu_entry_t *entry = lp_find_entry(id);
  if (!entry) {
    lp_menu_set_error("menu id not found");
    return 1;
  }
  if (entry->type == LP_MENU_ENTRY_MENU) {
    lp_menu_set_error("cannot set enabled on menu root");
    return 1;
  }
  if (!lp_set_item_enabled(entry->object, enabled ? 1 : 0)) {
    lp_menu_set_error("set enabled failed");
    return 1;
  }
  return 0;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_set_checked(const char *id, int32_t checked) {
  lp_menu_set_error(NULL);
  lp_menu_entry_t *entry = lp_find_entry(id);
  if (!entry) {
    lp_menu_set_error("menu id not found");
    return 1;
  }
  if (entry->type != LP_MENU_ENTRY_CHECK_ITEM) {
    lp_menu_set_error("entry is not a check menu item");
    return 1;
  }
  if (!lp_set_item_state(entry->object, checked ? 1 : 0)) {
    lp_menu_set_error("set checked failed");
    return 1;
  }
  return 0;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_set_text(const char *id, const char *text) {
  lp_menu_set_error(NULL);
  lp_menu_entry_t *entry = lp_find_entry(id);
  if (!entry) {
    lp_menu_set_error("menu id not found");
    return 1;
  }
  if (entry->type == LP_MENU_ENTRY_MENU) {
    lp_menu_set_error("cannot set text on menu root");
    return 1;
  }
  mb_sel_t sel_set_title = lp_sel("setTitle:");
  if (!sel_set_title) {
    lp_menu_set_error("setTitle selector unavailable");
    return 1;
  }
  mb_id_t ns_title = lp_nsstring(text ? text : "");
  if (!ns_title) {
    lp_menu_set_error("create title string failed");
    return 1;
  }
  ((mb_objc_msgsend_id_arg_t)g_objc.msgsend)(entry->object, sel_set_title, ns_title);
  return 0;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_set_accelerator(const char *id, const char *accelerator) {
  lp_menu_set_error(NULL);
  lp_menu_entry_t *entry = lp_find_entry(id);
  if (!entry) {
    lp_menu_set_error("menu id not found");
    return 1;
  }
  if (entry->type == LP_MENU_ENTRY_MENU || entry->type == LP_MENU_ENTRY_SUBMENU) {
    lp_menu_set_error("entry does not support accelerator");
    return 1;
  }
  if (!lp_apply_accelerator(entry->object, accelerator ? accelerator : "")) {
    lp_menu_set_error("invalid accelerator");
    return 1;
  }
  return 0;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_delete(const char *id) {
  lp_menu_set_error(NULL);
  lp_menu_entry_t *entry = lp_find_entry(id);
  if (!entry) {
    lp_menu_set_error("menu id not found");
    return 1;
  }
  lp_delete_entry_internal(entry);
  return 0;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t lp_menu_drain_events(void) {
  lp_menu_set_error(NULL);
  if (g_menu_event_count == 0) return lp_menu_bytes("");

  size_t total = 0;
  for (int i = 0; i < g_menu_event_count; i++) {
    total += strlen(g_menu_events[i]) + 1;
  }
  char *text = (char *)malloc(total + 1);
  if (!text) return lp_menu_bytes("");
  text[0] = '\0';
  for (int i = 0; i < g_menu_event_count; i++) {
    strcat(text, g_menu_events[i]);
    strcat(text, "\n");
  }

  moonbit_bytes_t out = lp_menu_bytes(text);
  free(text);
  lp_free_events();
  return out;
}

#else

MOONBIT_FFI_EXPORT int32_t lp_menu_clear_app_menu(void) {
  lp_menu_set_error("menu plugin is only supported on macOS");
  return 1;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_reset(void) {
  lp_menu_set_error("menu plugin is only supported on macOS");
  return 1;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_create_menu(const char *id) {
  (void)id;
  lp_menu_set_error("menu plugin is only supported on macOS");
  return 1;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_create_submenu(const char *id, const char *title,
                                                  int32_t enabled) {
  (void)id;
  (void)title;
  (void)enabled;
  lp_menu_set_error("menu plugin is only supported on macOS");
  return 1;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_create_item(const char *id, const char *text, int32_t enabled,
                                               const char *accelerator) {
  (void)id;
  (void)text;
  (void)enabled;
  (void)accelerator;
  lp_menu_set_error("menu plugin is only supported on macOS");
  return 1;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_create_check_item(const char *id, const char *text,
                                                     int32_t enabled, int32_t checked,
                                                     const char *accelerator) {
  (void)id;
  (void)text;
  (void)enabled;
  (void)checked;
  (void)accelerator;
  lp_menu_set_error("menu plugin is only supported on macOS");
  return 1;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_create_predefined_item(const char *id, const char *kind,
                                                          const char *text) {
  (void)id;
  (void)kind;
  (void)text;
  lp_menu_set_error("menu plugin is only supported on macOS");
  return 1;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_append(const char *parent_id, const char *child_id) {
  (void)parent_id;
  (void)child_id;
  lp_menu_set_error("menu plugin is only supported on macOS");
  return 1;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_insert(const char *parent_id, const char *child_id,
                                          int32_t position) {
  (void)parent_id;
  (void)child_id;
  (void)position;
  lp_menu_set_error("menu plugin is only supported on macOS");
  return 1;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_remove(const char *parent_id, const char *child_id) {
  (void)parent_id;
  (void)child_id;
  lp_menu_set_error("menu plugin is only supported on macOS");
  return 1;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_set_as_app_menu(const char *id) {
  (void)id;
  lp_menu_set_error("menu plugin is only supported on macOS");
  return 1;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_set_enabled(const char *id, int32_t enabled) {
  (void)id;
  (void)enabled;
  lp_menu_set_error("menu plugin is only supported on macOS");
  return 1;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_set_checked(const char *id, int32_t checked) {
  (void)id;
  (void)checked;
  lp_menu_set_error("menu plugin is only supported on macOS");
  return 1;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_set_text(const char *id, const char *text) {
  (void)id;
  (void)text;
  lp_menu_set_error("menu plugin is only supported on macOS");
  return 1;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_set_accelerator(const char *id, const char *accelerator) {
  (void)id;
  (void)accelerator;
  lp_menu_set_error("menu plugin is only supported on macOS");
  return 1;
}

MOONBIT_FFI_EXPORT int32_t lp_menu_delete(const char *id) {
  (void)id;
  lp_menu_set_error("menu plugin is only supported on macOS");
  return 1;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t lp_menu_drain_events(void) {
  return lp_menu_bytes("");
}

#endif
