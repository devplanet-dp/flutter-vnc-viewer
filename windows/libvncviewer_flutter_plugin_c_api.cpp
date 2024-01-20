#include "include/libvncviewer_flutter/libvncviewer_flutter_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "libvncviewer_flutter_plugin.h"

void LibvncviewerFlutterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  libvncviewer_flutter::LibvncviewerFlutterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
