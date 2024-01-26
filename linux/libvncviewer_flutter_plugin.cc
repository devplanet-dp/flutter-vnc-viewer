#include "include/libvncviewer_flutter/libvncviewer_flutter_plugin.h"

#include <flutter_linux/fl_value.h>
#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>
#include <iostream>
#include <map>
using namespace std;
#include "libvncviewer_flutter_plugin_private.h"
#include "my_texture.h"
#include "vncclient.h"

#define LIBVNCVIEWER_FLUTTER_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), libvncviewer_flutter_plugin_get_type(), \
                              LibvncviewerFlutterPlugin))

static map<int64_t, FlEventChannel *> eventChannelMap;

static FlTextureRegistrar *texutureRegistrar;

struct _LibvncviewerFlutterPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(LibvncviewerFlutterPlugin, libvncviewer_flutter_plugin,
              g_object_get_type())

void rfbClientCallback(int64_t id, int code, string flag, string msg) {
  g_autoptr(FlValue) data_map = fl_value_new_map();
  fl_value_set(data_map, fl_value_new_string("flag"),
               fl_value_new_string("onError"));
  fl_value_set(data_map, fl_value_new_string("msg"),
               fl_value_new_string(msg.c_str()));
  fl_event_channel_send(eventChannelMap[id], data_map, NULL, NULL);
}

// Called when a method call is received from Flutter.
static void libvncviewer_flutter_plugin_handle_method_call(
    LibvncviewerFlutterPlugin *self, FlMethodCall *method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar *method = fl_method_call_get_name(method_call);
  FlValue *value = fl_method_call_get_args(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    response = get_platform_version();
  }
  if (strcmp(method, "closeVncClient") == 0) {
    int size = 0;
    value = fl_value_get_map_value(value, size);
    int64_t clientId = fl_value_get_int(value);
    VncClient::getClient(clientId)->release();
  }
  if (strcmp(method, "startVncClient") == 0) {
    value = fl_value_get_map_value(value, 0);
    int64_t clientId = fl_value_get_int(value);
    VncClient::getClient(clientId)->connect();
  }

  if (strcmp(method, "sendPointer") == 0) {
    FlValue *value = fl_method_call_get_args(method_call);
    int64_t clientId = fl_value_get_int(fl_value_get_map_value(value, 0));
    int64_t x = fl_value_get_int(fl_value_get_map_value(value, 1));
    int64_t y = fl_value_get_int(fl_value_get_map_value(value, 2));
    int64_t button_mask = fl_value_get_int(fl_value_get_map_value(value, 3));
    VncClient::getClient(clientId)->sendPointer(x, y, button_mask);
  }
  if (strcmp(method, "initVncClient") == 0) {
    const gchar *hostname =
        fl_value_get_string(fl_value_get_map_value(value, 0));

    printf("hostname ==> %s\n", hostname);
    int64_t port = fl_value_get_int(fl_value_get_map_value(value, 1));
    printf("port ==> %ld\n", port);
    const gchar *password =
        fl_value_get_string(fl_value_get_map_value(value, 2));
    printf("password ==> %s\n", password);
    response = initVncClient(hostname, port, password);
  }

#if 0
  else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
#endif
  fl_method_call_respond(method_call, response, nullptr);
}

FlMethodResponse *get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse *initVncClient(const gchar *hostname, int64_t port,
                                const gchar *password) {
  auto *client = new VncClient(string(hostname), (int)port, string(password));
  client->registerErrorCallback(rfbClientCallback);
  auto imageResizeCallBack = [=](int w, int h) {
    MyTexture *texture = my_texture_new(w, h, 0, 0, 0);
    if (!fl_texture_registrar_register_texture(texutureRegistrar,
                                               FL_TEXTURE(texture))) {
      return;
    }
    client->texture = texture;
    g_autoptr(FlValue) data_map = fl_value_new_map();
    fl_value_set(data_map, fl_value_new_string("width"), fl_value_new_int(w));
    fl_value_set(data_map, fl_value_new_string("height"), fl_value_new_int(h));
    fl_value_set(data_map, fl_value_new_string("textureId"),
                 fl_value_new_int(fl_texture_get_id(FL_TEXTURE(texture))));
    fl_value_set(data_map, fl_value_new_string("flag"),
                 fl_value_new_string("imageResize"));
    fl_event_channel_send(eventChannelMap[client->id], data_map, NULL, NULL);
  };
  client->imageResizeCallBack = imageResizeCallBack;
  client->frameUpdateCallBack = [=](uint8_t *data, int w, int h) {
    fl_texture_registrar_mark_texture_frame_available(
        texutureRegistrar, FL_TEXTURE(client->texture));
  };
  client->initRfbClient();
  g_autoptr(FlValue) result = fl_value_new_int(client->id);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static void libvncviewer_flutter_plugin_dispose(GObject *object) {
  G_OBJECT_CLASS(libvncviewer_flutter_plugin_parent_class)->dispose(object);
}

static void libvncviewer_flutter_plugin_class_init(
    LibvncviewerFlutterPluginClass *klass) {
  G_OBJECT_CLASS(klass)->dispose = libvncviewer_flutter_plugin_dispose;
}

static void libvncviewer_flutter_plugin_init(LibvncviewerFlutterPlugin *self) {}

static void method_call_cb(FlMethodChannel *channel, FlMethodCall *method_call,
                           gpointer user_data) {
  LibvncviewerFlutterPlugin *plugin = LIBVNCVIEWER_FLUTTER_PLUGIN(user_data);
  libvncviewer_flutter_plugin_handle_method_call(plugin, method_call);
}

static FlMethodErrorResponse *listen_handler(FlEventChannel *channel,
                                             FlValue *args,
                                             gpointer user_data) {
  int64_t clientId = fl_value_get_int(fl_value_get_map_value(args, 0));
  eventChannelMap[clientId] = channel;
  //  g_autofree gchar *resData = g_strdup_printf("{\"flag\":\"%s\"}",
  //  "onReady"); g_autoptr(FlValue) message = fl_value_new_string(resData);
  //  g_autoptr(GError) error = NULL;
  //  if (!fl_event_channel_send(channel, message, NULL, &error)) {
  //    g_warning("Failed to send event: %s", error->message);
  //  }

  g_autoptr(FlValue) data_map = fl_value_new_map();
  fl_value_set(data_map, fl_value_new_string("flag"),
               fl_value_new_string("onReady"));
  fl_event_channel_send(channel, data_map, NULL, NULL);

  return NULL;
}
static FlMethodErrorResponse *cancel_handler(FlEventChannel *channel,
                                             FlValue *args,
                                             gpointer user_data) {
  int64_t clientId = fl_value_get_int(fl_value_get_map_value(args, 0));
  eventChannelMap.erase(clientId);
  return NULL;
}

void libvncviewer_flutter_plugin_register_with_registrar(
    FlPluginRegistrar *registrar) {
  LibvncviewerFlutterPlugin *plugin = LIBVNCVIEWER_FLUTTER_PLUGIN(
      g_object_new(libvncviewer_flutter_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "libvncviewer_flutter", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_autoptr(FlEventChannel) event_channel = fl_event_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "libvncviewer_flutter_eventchannel", FL_METHOD_CODEC(codec));

  fl_event_channel_set_stream_handlers(event_channel, listen_handler,
                                       cancel_handler, g_object_ref(plugin),
                                       g_object_unref);
  texutureRegistrar = fl_plugin_registrar_get_texture_registrar(registrar);
  g_object_unref(plugin);
}
