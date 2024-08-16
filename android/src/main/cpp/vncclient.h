#ifndef VNCCLIENT_H
#define VNCCLIENT_H

#include <android/native_window_jni.h>
#include <jni.h>
#include <rfb/rfbclient.h>

#include <functional>
#include <iostream>
#include <map>
using namespace std;

class VncClient {
public:
  VncClient(string hostName, int port, string password, JavaVM *javaVM,
            jobject javaObj, jobject surfaceObj);
  int64_t id;
  string hostName;
  int port;
  string password;
  rfbClient *cl;
  uint8_t *frameBuffer = NULL;
  int frameBufferSize = 0;
  JavaVM *javaVM = NULL;
  jobject javaObj = NULL;    //全局Jobject变量
  jobject surfaceObj = NULL; //全局Jobject变量

  int width = 0;
  int height = 0;

  bool running = true;

  void initRfbClient();

  void connect();

  void close();

  static VncClient *getVncClient(int64_t id);

  void sendPointer(int x, int y, int buttonMask);

  void sendKeyEvent(int key,  bool down);

  void sendErrorMsg(string msg);

private:
  static map<int64_t, VncClient *> clientMap;
};

#endif // VNCCLIENT_H
