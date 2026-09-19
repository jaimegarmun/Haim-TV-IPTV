#include "my_application.h"

int main(int argc, char** argv) {
  // The desktop uses these to match the window with its .desktop file
  // (Wayland app_id and X11 WM_CLASS). Without it the taskbar shows a
  // generic icon and the app can't be pinned.
  g_set_prgname(APPLICATION_ID);
  gdk_set_program_class(APPLICATION_ID);
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
