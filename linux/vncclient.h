#ifndef VNCCLIENT_H
#define VNCCLIENT_H
#include <iostream>
#include <map>
extern "C" {
#include <rfb/rfbclient.h>
}
#include <functional>
#include <unistd.h>
#include "my_texture.h"
using namespace std;

typedef void (*ErrorCallback)(int64_t id, int code, string flag, string msg);

typedef void (*FrameCallBack)(uint8_t *data, int width, int height);

class VncClient {
public:
  VncClient(string hostName, int port, string password);
  string hostName;
  int port;
  string password;
  uint8_t *frameBuffer = NULL;

  int64_t id;

  int colorDepth;

  int width;

  int height;

  int frameBufferSize;

  MyTexture* texture;

  std::function<void(int,int)> imageResizeCallBack = NULL;

  std::function<void(uint8_t *, int, int)> frameUpdateCallBack = NULL;

  void release();

  void initRfbClient();

  void connect();

  void registerErrorCallback(ErrorCallback callback);

  void sendPointer(int x, int y, int buttonMask);

  void sendKey(int key, bool upOrDown);

  static VncClient *getClient(int64_t id);

private:
  rfbClient *cl;

  bool running = true;

  ErrorCallback errorCallback = NULL;

  FrameCallBack frameCallBack = NULL;

  static map<int64_t, VncClient *> clientMap;
};

#endif // VNCCLIENT_H
