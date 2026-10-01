#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include <cstring>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Window geometry remembered between runs.
struct WindowState {
  int x;
  int y;
  int width;
  int height;
  gboolean maximized;
};

// A window smaller than this is treated as corrupt rather than restored.
static const int kMinRestoredWidth = 400;
static const int kMinRestoredHeight = 300;
static const int kMaxRestoredSize = 30000;

// Path of the geometry file. Inside the Flatpak sandbox the config dir is
// already writable, so no extra permission is needed.
static gchar* window_state_path() {
  return g_build_filename(g_get_user_config_dir(), APPLICATION_ID,
                          "window_state.json", nullptr);
}

// Minimal readers for the flat JSON object written by save_window_state(). A
// real parser would mean a new dependency, which this project can't take.
static gboolean read_json_int(const gchar* json, const gchar* name,
                              int* value) {
  g_autofree gchar* key = g_strdup_printf("\"%s\"", name);
  const gchar* at = strstr(json, key);
  if (at == nullptr) {
    return FALSE;
  }
  at = strchr(at + strlen(key), ':');
  if (at == nullptr) {
    return FALSE;
  }
  *value = (int)g_ascii_strtoll(at + 1, nullptr, 10);
  return TRUE;
}

static gboolean read_json_bool(const gchar* json, const gchar* name,
                               gboolean* value) {
  g_autofree gchar* key = g_strdup_printf("\"%s\"", name);
  const gchar* at = strstr(json, key);
  if (at == nullptr) {
    return FALSE;
  }
  at = strchr(at + strlen(key), ':');
  if (at == nullptr) {
    return FALSE;
  }
  at++;
  while (*at == ' ' || *at == '\t') {
    at++;
  }
  *value = g_str_has_prefix(at, "true");
  return TRUE;
}

// TRUE when the saved rectangle still overlaps a connected monitor, so a
// window saved on a screen that has been unplugged is not restored off-screen.
static gboolean rect_is_on_a_monitor(const WindowState* state) {
  GdkDisplay* display = gdk_display_get_default();
  if (display == nullptr) {
    return FALSE;
  }
  GdkRectangle window_rect = {state->x, state->y, state->width, state->height};
  int n_monitors = gdk_display_get_n_monitors(display);
  for (int i = 0; i < n_monitors; i++) {
    GdkMonitor* monitor = gdk_display_get_monitor(display, i);
    if (monitor == nullptr) {
      continue;
    }
    GdkRectangle monitor_rect;
    gdk_monitor_get_geometry(monitor, &monitor_rect);
    if (gdk_rectangle_intersect(&monitor_rect, &window_rect, nullptr)) {
      return TRUE;
    }
  }
  return FALSE;
}

// Reads back the state saved by the previous run. FALSE means the caller keeps
// its own defaults.
static gboolean load_window_state(WindowState* state) {
  g_autofree gchar* path = window_state_path();
  g_autofree gchar* contents = nullptr;
  if (!g_file_get_contents(path, &contents, nullptr, nullptr)) {
    return FALSE;
  }

  WindowState loaded = {0, 0, 0, 0, FALSE};
  if (!read_json_int(contents, "x", &loaded.x) ||
      !read_json_int(contents, "y", &loaded.y) ||
      !read_json_int(contents, "width", &loaded.width) ||
      !read_json_int(contents, "height", &loaded.height)) {
    return FALSE;
  }
  read_json_bool(contents, "maximized", &loaded.maximized);

  if (loaded.width < kMinRestoredWidth || loaded.height < kMinRestoredHeight ||
      loaded.width > kMaxRestoredSize || loaded.height > kMaxRestoredSize) {
    return FALSE;
  }

  *state = loaded;
  return TRUE;
}

// Writes the geometry of |window|. While maximized, gtk_window_get_size()
// returns the maximized size, so the un-maximized size is not available; the
// maximized flag is stored and the previous rectangle on disk is kept.
static void save_window_state(GtkWindow* window) {
  gboolean maximized = gtk_window_is_maximized(window);

  WindowState state = {0, 0, 0, 0, maximized};
  gboolean have_rect = FALSE;
  if (maximized) {
    // Keep the restored rectangle from the last time the window was not
    // maximized, if there is one.
    WindowState previous;
    if (load_window_state(&previous)) {
      state.x = previous.x;
      state.y = previous.y;
      state.width = previous.width;
      state.height = previous.height;
      have_rect = TRUE;
    }
  } else {
    // Note: under Wayland gtk_window_get_position() cannot report a global
    // position (and gtk_window_move() is ignored), so only the size is
    // effectively remembered there.
    gtk_window_get_position(window, &state.x, &state.y);
    gtk_window_get_size(window, &state.width, &state.height);
    have_rect = state.width > 0 && state.height > 0;
  }
  if (!have_rect) {
    return;
  }

  g_autofree gchar* dir =
      g_build_filename(g_get_user_config_dir(), APPLICATION_ID, nullptr);
  if (g_mkdir_with_parents(dir, 0755) != 0) {
    return;
  }
  g_autofree gchar* path = window_state_path();
  g_autofree gchar* json = g_strdup_printf(
      "{\"x\":%d,\"y\":%d,\"width\":%d,\"height\":%d,\"maximized\":%s}\n",
      state.x, state.y, state.width, state.height,
      state.maximized ? "true" : "false");
  g_file_set_contents(path, json, -1, nullptr);
}

// Only one window exists, and its geometry is only written once per run.
static gboolean window_state_saved = FALSE;

// Save the geometry before the window goes away. Returning FALSE lets GTK
// carry on closing it.
static gboolean on_window_delete_event(GtkWidget* widget, GdkEvent* event,
                                       gpointer user_data) {
  (void)event;
  (void)user_data;
  if (!window_state_saved) {
    save_window_state(GTK_WINDOW(widget));
    window_state_saved = TRUE;
  }
  return FALSE;
}

// Fallback for a window closed without a delete-event (e.g. the application
// quitting on its own).
static void on_window_destroy(GtkWidget* widget, gpointer user_data) {
  (void)user_data;
  if (!window_state_saved) {
    save_window_state(GTK_WINDOW(widget));
    window_state_saved = TRUE;
  }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

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
    gtk_header_bar_set_title(header_bar, "Haim TV");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Haim TV");
  }

  // Themed icon installed by the Flatpak; otherwise the bundled one.
  gtk_window_set_icon_name(window, APPLICATION_ID);
  g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
  if (exe_path != nullptr) {
    g_autofree gchar* exe_dir = g_path_get_dirname(exe_path);
    g_autofree gchar* icon_path = g_build_filename(
        exe_dir, "data", "flutter_assets", "assets", "icon.png", nullptr);
    if (g_file_test(icon_path, G_FILE_TEST_EXISTS)) {
      gtk_window_set_icon_from_file(window, icon_path, nullptr);
    }
  }

  // Restore the geometry of the previous run, falling back to the default size
  // on the first run or when the saved rectangle is no longer usable.
  WindowState state;
  if (load_window_state(&state)) {
    gtk_window_set_default_size(window, state.width, state.height);
    if (rect_is_on_a_monitor(&state)) {
      gtk_window_move(window, state.x, state.y);
    }
    if (state.maximized) {
      gtk_window_maximize(window);
    }
  } else {
    gtk_window_set_default_size(window, 1280, 720);
  }
  g_signal_connect(window, "delete-event",
                   G_CALLBACK(on_window_delete_event), nullptr);
  g_signal_connect(window, "destroy", G_CALLBACK(on_window_destroy), nullptr);

  gtk_widget_show(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
