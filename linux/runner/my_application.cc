#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <gio/gio.h>
#include <glib-unix.h>
#include <glib/gstdio.h>
#include <limits.h>
#include <signal.h>
#include <unistd.h>
#include <cstring>
#include <vector>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr const char* kAuthChannelName = "me.neon16bit.savedex/reddit_auth";
constexpr const char* kHandlerDesktopFilename = "savedex-oauth-handler.desktop";

bool is_allowed_custom_scheme(const gchar* scheme) {
  if (scheme == nullptr) {
    return false;
  }
  const gsize len = std::strlen(scheme);
  if (len == 0 || len > 64) {
    return false;
  }
  const unsigned char first = static_cast<unsigned char>(scheme[0]);
  if (first < 'a' || first > 'z') {
    return false;
  }
  for (gsize i = 1; i < len; ++i) {
    const unsigned char ch = static_cast<unsigned char>(scheme[i]);
    const bool is_lower = (ch >= 'a' && ch <= 'z');
    const bool is_digit = (ch >= '0' && ch <= '9');
    if (!is_lower && !is_digit && ch != '+' && ch != '-' && ch != '.') {
      return false;
    }
  }

  static constexpr const char* kReservedSchemes[] = {
      "http",   "https",     "file",     "ftp",    "mailto",   "tel",
      "javascript", "data",  "vbscript", "about",  "blob",     "chrome",
      "edge",   "shell",     "ssh",      "sftp",   "smb",      "apt",
      "snap",   "flatpak",   "magnet",   "irc",    "help",     "man",
      "info",   "trash",
  };
  for (const char* reserved : kReservedSchemes) {
    if (std::strcmp(scheme, reserved) == 0) {
      return false;
    }
  }
  return true;
}

bool is_safe_auth_url(const gchar* url) {
  if (url == nullptr || g_ascii_strncasecmp(url, "https://", 8) != 0) {
    return false;
  }
  const gchar* after_scheme = url + 8;
  if (*after_scheme == '\0' || *after_scheme == '/' || *after_scheme == '?' ||
      *after_scheme == '#') {
    return false;
  }
  for (const gchar* p = url; *p != '\0'; ++p) {
    const unsigned char ch = static_cast<unsigned char>(*p);
    if (ch <= 0x20 || ch == 0x7F) {
      return false;
    }
  }
  return true;
}

bool has_control_chars(const gchar* s) {
  if (s == nullptr) {
    return true;
  }
  for (const gchar* p = s; *p != '\0'; ++p) {
    const unsigned char ch = static_cast<unsigned char>(*p);
    if (ch < 0x20 || ch == 0x7F) {
      return true;
    }
  }
  return false;
}

void refresh_desktop_database(const gchar* apps_dir) {
  if (apps_dir == nullptr || apps_dir[0] == '\0') {
    return;
  }
  gchar cmd[] = "update-desktop-database";
  g_autofree gchar* dir_arg = g_strdup(apps_dir);
  gchar* argv[] = {cmd, dir_arg, nullptr};
  gint exit_status = -1;
  g_spawn_sync(nullptr, argv, nullptr,
               static_cast<GSpawnFlags>(G_SPAWN_SEARCH_PATH |
                                        G_SPAWN_STDOUT_TO_DEV_NULL |
                                        G_SPAWN_STDERR_TO_DEV_NULL),
               nullptr, nullptr, nullptr, nullptr, &exit_status, nullptr);
}

gchar* escape_desktop_exec_path(const gchar* exe_path) {
  GString* out = g_string_new("");
  for (const gchar* p = exe_path; *p != '\0'; ++p) {
    if (*p == '\\') {
      g_string_append(out, "\\\\\\\\");
    } else if (*p == '"' || *p == '$' || *p == '`') {
      g_string_append(out, "\\\\");
      g_string_append_c(out, *p);
    } else if (*p == '%') {
      g_string_append(out, "%%");
    } else {
      g_string_append_c(out, *p);
    }
  }
  return g_string_free(out, FALSE);
}

gchar* query_default_scheme_handler(const gchar* scheme) {
  g_autofree gchar* mime_type = g_strdup_printf("x-scheme-handler/%s", scheme);
  gchar cmd[] = "xdg-mime";
  gchar subcmd[] = "query";
  gchar what[] = "default";
  gchar* argv[] = {cmd, subcmd, what, mime_type, nullptr};

  g_autofree gchar* stdout_buf = nullptr;
  gint exit_status = -1;
  if (!g_spawn_sync(nullptr, argv, nullptr,
                    static_cast<GSpawnFlags>(G_SPAWN_SEARCH_PATH |
                                             G_SPAWN_STDERR_TO_DEV_NULL),
                    nullptr, nullptr, &stdout_buf, nullptr, &exit_status,
                    nullptr) ||
      exit_status != 0 || stdout_buf == nullptr) {
    return nullptr;
  }

  gchar* trimmed = g_strstrip(stdout_buf);
  if (trimmed[0] == '\0' ||
      std::strcmp(trimmed, kHandlerDesktopFilename) == 0) {
    return nullptr;
  }
  return g_strdup(trimmed);
}

void remove_dangling_mimeapps_entry(const gchar* scheme,
                                    gboolean include_default_group) {
  g_autofree gchar* mimeapps_path =
      g_build_filename(g_get_user_config_dir(), "mimeapps.list", nullptr);
  g_autoptr(GKeyFile) key_file = g_key_file_new();
  if (!g_key_file_load_from_file(key_file, mimeapps_path,
                                 G_KEY_FILE_KEEP_COMMENTS, nullptr)) {
    return;
  }

  g_autofree gchar* mime_key = g_strdup_printf("x-scheme-handler/%s", scheme);
  std::vector<const char*> groups;
  groups.push_back("Added Associations");
  if (include_default_group) {
    groups.push_back("Default Applications");
  }

  gboolean modified = FALSE;
  for (const char* group : groups) {
    gsize list_len = 0;
    gchar** entries = g_key_file_get_string_list(key_file, group, mime_key,
                                                 &list_len, nullptr);
    if (entries == nullptr) {
      continue;
    }

    std::vector<const gchar*> kept;
    kept.reserve(list_len);
    bool removed = false;
    for (gsize i = 0; i < list_len; ++i) {
      if (entries[i] == nullptr) {
        continue;
      }
      gchar* item = g_strstrip(entries[i]);
      if (std::strcmp(item, kHandlerDesktopFilename) == 0) {
        removed = true;
      } else if (item[0] != '\0') {
        kept.push_back(item);
      }
    }

    if (removed) {
      if (kept.empty()) {
        if (g_key_file_remove_key(key_file, group, mime_key, nullptr)) {
          modified = TRUE;
        }
      } else {
        g_key_file_set_string_list(key_file, group, mime_key, kept.data(),
                                   kept.size());
        modified = TRUE;
      }
    }

    g_strfreev(entries);
  }

  if (modified) {
    g_key_file_save_to_file(key_file, mimeapps_path, nullptr);
  }
}

void respond_error(FlMethodCall* method_call,
                   const gchar* code,
                   const gchar* message) {
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_error_response_new(code, message, nullptr));
  fl_method_call_respond(method_call, response, nullptr);
}

void respond_success_string(FlMethodCall* method_call, const gchar* value) {
  g_autoptr(FlValue) fl_val =
      value != nullptr ? fl_value_new_string(value) : nullptr;
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_success_response_new(fl_val));
  fl_method_call_respond(method_call, response, nullptr);
}

}  // namespace

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  GtkWindow* window;
  FlMethodChannel* auth_channel;
  FlMethodCall* pending_auth_call;
  gchar* pending_auth_scheme;
  gchar* registered_desktop_file;
  gchar* registered_scheme;
  gchar* previous_scheme_handler;
  guint sigterm_source_id;
  guint sigint_source_id;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static void restore_scheme_handler(MyApplication* self) {
  if (self->registered_desktop_file != nullptr) {
    g_autofree gchar* apps_dir =
        g_path_get_dirname(self->registered_desktop_file);
    g_unlink(self->registered_desktop_file);
    g_clear_pointer(&self->registered_desktop_file, g_free);
    refresh_desktop_database(apps_dir);
  }

  if (self->registered_scheme != nullptr) {
    if (self->previous_scheme_handler != nullptr) {
      g_autofree gchar* mime_type =
          g_strdup_printf("x-scheme-handler/%s", self->registered_scheme);
      gchar cmd[] = "xdg-mime";
      gchar subcmd[] = "default";
      gchar* xdg_argv[] = {
          cmd, subcmd, self->previous_scheme_handler, mime_type, nullptr};
      gint exit_status = -1;
      const gboolean restored =
          g_spawn_sync(nullptr, xdg_argv, nullptr,
                       static_cast<GSpawnFlags>(G_SPAWN_SEARCH_PATH |
                                                G_SPAWN_STDERR_TO_DEV_NULL),
                       nullptr, nullptr, nullptr, nullptr, &exit_status,
                       nullptr) &&
          exit_status == 0;
      remove_dangling_mimeapps_entry(self->registered_scheme,
                                     restored ? FALSE : TRUE);
    } else {
      remove_dangling_mimeapps_entry(self->registered_scheme, TRUE);
    }
    g_clear_pointer(&self->registered_scheme, g_free);
  }

  g_clear_pointer(&self->previous_scheme_handler, g_free);
}

static void cancel_pending_auth(MyApplication* self,
                                gboolean notify_canceled) {
  FlMethodCall* call = self->pending_auth_call;
  self->pending_auth_call = nullptr;
  g_clear_pointer(&self->pending_auth_scheme, g_free);
  restore_scheme_handler(self);
  if (call != nullptr) {
    if (notify_canceled) {
      respond_error(call, "CANCELED", "Authorization was canceled.");
    }
    g_object_unref(call);
  }
}

static gboolean register_custom_scheme_handler(MyApplication* self,
                                              const gchar* scheme,
                                              gchar** error_out) {
  restore_scheme_handler(self);

  char exe_buf[PATH_MAX];
  const ssize_t exe_len =
      readlink("/proc/self/exe", exe_buf, sizeof(exe_buf) - 1);
  if (exe_len <= 0 || exe_len >= static_cast<ssize_t>(sizeof(exe_buf) - 1)) {
    if (error_out != nullptr) {
      *error_out = g_strdup("Could not resolve Savedex executable path.");
    }
    return FALSE;
  }
  exe_buf[exe_len] = '\0';
  if (has_control_chars(exe_buf)) {
    if (error_out != nullptr) {
      *error_out = g_strdup("Savedex executable path contains invalid characters.");
    }
    return FALSE;
  }

  g_autofree gchar* apps_dir =
      g_build_filename(g_get_user_data_dir(), "applications", nullptr);
  if (g_mkdir_with_parents(apps_dir, 0755) != 0) {
    if (error_out != nullptr) {
      *error_out = g_strdup("Could not create local applications directory.");
    }
    return FALSE;
  }

  g_autofree gchar* previous_handler = query_default_scheme_handler(scheme);
  g_autofree gchar* desktop_path =
      g_build_filename(apps_dir, kHandlerDesktopFilename, nullptr);
  g_autofree gchar* escaped_exe = escape_desktop_exec_path(exe_buf);
  g_autofree gchar* content = g_strdup_printf(
      "[Desktop Entry]\n"
      "Type=Application\n"
      "Name=Savedex OAuth Redirect\n"
      "Exec=\"%s\" %%u\n"
      "Terminal=false\n"
      "NoDisplay=true\n"
      "MimeType=x-scheme-handler/%s;\n",
      escaped_exe, scheme);

  g_autoptr(GError) write_error = nullptr;
  if (!g_file_set_contents(desktop_path, content, -1, &write_error)) {
    if (error_out != nullptr) {
      *error_out = g_strdup(write_error != nullptr
                                ? write_error->message
                                : "Failed to write desktop handler file.");
    }
    return FALSE;
  }

  refresh_desktop_database(apps_dir);

  g_autofree gchar* mime_type = g_strdup_printf("x-scheme-handler/%s", scheme);
  gchar cmd[] = "xdg-mime";
  gchar subcmd[] = "default";
  g_autofree gchar* desktop_id = g_strdup(kHandlerDesktopFilename);
  gchar* xdg_argv[] = {cmd, subcmd, desktop_id, mime_type, nullptr};

  gint exit_status = -1;
  g_autoptr(GError) spawn_error = nullptr;
  const gboolean spawned = g_spawn_sync(
      nullptr, xdg_argv, nullptr,
      static_cast<GSpawnFlags>(G_SPAWN_SEARCH_PATH |
                               G_SPAWN_STDERR_TO_DEV_NULL),
      nullptr, nullptr, nullptr, nullptr, &exit_status, &spawn_error);
  if (!spawned || exit_status != 0) {
    g_unlink(desktop_path);
    refresh_desktop_database(apps_dir);
    if (error_out != nullptr) {
      *error_out = g_strdup(
          spawn_error != nullptr
              ? spawn_error->message
              : "xdg-mime failed to register the custom URL scheme.");
    }
    return FALSE;
  }

  self->registered_desktop_file = g_strdup(desktop_path);
  self->registered_scheme = g_strdup(scheme);
  self->previous_scheme_handler =
      static_cast<gchar*>(g_steal_pointer(&previous_handler));
  return TRUE;
}

static void auth_method_call_cb(FlMethodChannel* channel,
                                FlMethodCall* method_call,
                                gpointer user_data) {
  (void)channel;
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(method_call);

  if (std::strcmp(method, "startDesktopCustomSchemeAuth") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      respond_error(method_call, "INVALID_ARGS",
                    "Expected map arguments for OAuth launch.");
      return;
    }

    FlValue* auth_val = fl_value_lookup_string(args, "authUrl");
    FlValue* scheme_val = fl_value_lookup_string(args, "callbackScheme");
    if (auth_val == nullptr ||
        fl_value_get_type(auth_val) != FL_VALUE_TYPE_STRING ||
        scheme_val == nullptr ||
        fl_value_get_type(scheme_val) != FL_VALUE_TYPE_STRING) {
      respond_error(method_call, "INVALID_ARGS",
                    "Missing authUrl or callbackScheme argument.");
      return;
    }

    const gchar* auth_url = fl_value_get_string(auth_val);
    g_autofree gchar* scheme =
        g_ascii_strdown(fl_value_get_string(scheme_val), -1);
    if (!is_allowed_custom_scheme(scheme) || !is_safe_auth_url(auth_url)) {
      respond_error(method_call, "INVALID_REDIRECT_URI",
                    "Invalid custom callback scheme or authorization URL.");
      return;
    }

    cancel_pending_auth(self, TRUE);

    g_autofree gchar* reg_error = nullptr;
    if (!register_custom_scheme_handler(self, scheme, &reg_error)) {
      respond_error(method_call, "SCHEME_REGISTER_FAILED",
                    reg_error != nullptr
                        ? reg_error
                        : "Failed to register custom URL scheme handler.");
      return;
    }

    g_autoptr(GError) launch_error = nullptr;
    const gboolean launched =
        self->window != nullptr
            ? gtk_show_uri_on_window(self->window, auth_url, GDK_CURRENT_TIME,
                                     &launch_error)
            : g_app_info_launch_default_for_uri(auth_url, nullptr,
                                                &launch_error);
    if (!launched) {
      restore_scheme_handler(self);
      respond_error(method_call, "BROWSER_LAUNCH_FAILED",
                    launch_error != nullptr ? launch_error->message
                                            : "Could not open system browser.");
      return;
    }

    self->pending_auth_call = FL_METHOD_CALL(g_object_ref(method_call));
    self->pending_auth_scheme = g_strdup(scheme);
    return;
  }

  if (std::strcmp(method, "cancelDesktopCustomSchemeAuth") == 0) {
    cancel_pending_auth(self, TRUE);
    respond_success_string(method_call, nullptr);
    return;
  }

  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  fl_method_call_respond(method_call, response, nullptr);
}

static void on_window_destroy(GtkWidget* widget, gpointer user_data) {
  (void)widget;
  MyApplication* self = MY_APPLICATION(user_data);
  self->window = nullptr;
  if (self->auth_channel != nullptr) {
    fl_method_channel_set_method_call_handler(self->auth_channel, nullptr,
                                              nullptr, nullptr);
    g_clear_object(&self->auth_channel);
  }
  cancel_pending_auth(self, FALSE);
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  if (self->window != nullptr) {
    gtk_window_present(self->window);
    return;
  }

  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  self->window = window;
  g_signal_connect(window, "destroy", G_CALLBACK(on_window_destroy), self);

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "savedex");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "savedex");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlBinaryMessenger* messenger =
      fl_engine_get_binary_messenger(fl_view_get_engine(view));
  g_clear_object(&self->auth_channel);
  self->auth_channel = fl_method_channel_new(messenger, kAuthChannelName,
                                             FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->auth_channel, auth_method_call_cb, self, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::command_line.
static int my_application_command_line(GApplication* application,
                                       GApplicationCommandLine* command_line) {
  MyApplication* self = MY_APPLICATION(application);
  gint argc = 0;
  gchar** argv = g_application_command_line_get_arguments(command_line, &argc);

  if (self->window != nullptr) {
    gtk_window_present(self->window);
    if (self->pending_auth_call != nullptr &&
        self->pending_auth_scheme != nullptr) {
      const gsize scheme_len = std::strlen(self->pending_auth_scheme);
      for (gint i = 1; i < argc; ++i) {
        const gchar* candidate = argv[i];
        if (candidate != nullptr &&
            g_ascii_strncasecmp(candidate, self->pending_auth_scheme,
                                scheme_len) == 0 &&
            std::strncmp(candidate + scheme_len, "://", 3) == 0 &&
            g_utf8_validate(candidate, -1, nullptr)) {
          FlMethodCall* call = self->pending_auth_call;
          self->pending_auth_call = nullptr;
          g_clear_pointer(&self->pending_auth_scheme, g_free);
          restore_scheme_handler(self);
          respond_success_string(call, candidate);
          g_object_unref(call);
          break;
        }
      }
    }
  } else {
    g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
    if (argc > 1) {
      self->dart_entrypoint_arguments = g_strdupv(argv + 1);
    }
    g_application_activate(application);
  }

  g_strfreev(argv);
  return 0;
}

static gboolean on_sigterm(gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->sigterm_source_id = 0;
  g_application_quit(G_APPLICATION(self));
  return G_SOURCE_REMOVE;
}

static gboolean on_sigint(gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->sigint_source_id = 0;
  g_application_quit(G_APPLICATION(self));
  return G_SOURCE_REMOVE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  self->sigterm_source_id = g_unix_signal_add(SIGTERM, on_sigterm, self);
  self->sigint_source_id = g_unix_signal_add(SIGINT, on_sigint, self);
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  cancel_pending_auth(self, FALSE);
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  if (self->sigterm_source_id != 0) {
    g_source_remove(self->sigterm_source_id);
    self->sigterm_source_id = 0;
  }
  if (self->sigint_source_id != 0) {
    g_source_remove(self->sigint_source_id);
    self->sigint_source_id = 0;
  }
  cancel_pending_auth(self, FALSE);
  if (self->auth_channel != nullptr) {
    fl_method_channel_set_method_call_handler(self->auth_channel, nullptr,
                                              nullptr, nullptr);
    g_clear_object(&self->auth_channel);
  }
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->command_line = my_application_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(
      my_application_get_type(), "application-id", APPLICATION_ID, "flags",
      G_APPLICATION_HANDLES_COMMAND_LINE, nullptr));
}
