#include "vncclient.h"

#include <android/log.h>

#include <thread>

map<int64_t, VncClient *> VncClient::clientMap;

static char *ReadPassword(rfbClient *client) {
  VncClient *vncClient = (VncClient *)rfbClientGetClientData(client, 0);
  char *password = (char *)malloc(vncClient->password.size());
  memset(password, 0, vncClient->password.size());
  memcpy(password, vncClient->password.c_str(), vncClient->password.size());
  return password;
}

static rfbCredential *get_credential(rfbClient *cl, int credentialType) {
  rfbCredential *c = (rfbCredential *)malloc(sizeof(rfbCredential));
  if (!c) {
    return NULL;
  }
  c->userCredential.username = (char *)malloc(RFB_BUF_SIZE);
  if (!c->userCredential.username) {
    free(c);
    return NULL;
  }
  c->userCredential.password = (char *)malloc(RFB_BUF_SIZE);
  if (!c->userCredential.password) {
    free(c->userCredential.username);
    free(c);
    return NULL;
  }

  if (credentialType != rfbCredentialTypeUser) {
    rfbClientErr("something else than username and password required for "
                 "authentication\n");
    return NULL;
  }

  rfbClientLog("username and password required for authentication!\n");
  printf("user: ");
  fgets(c->userCredential.username, RFB_BUF_SIZE, stdin);
  printf("pass: ");
  fgets(c->userCredential.password, RFB_BUF_SIZE, stdin);

  /* remove trailing newlines */
  c->userCredential.username[strcspn(c->userCredential.username, "\n")] = 0;
  c->userCredential.password[strcspn(c->userCredential.password, "\n")] = 0;

  return c;
}

static rfbBool resize(rfbClient *client) {
  int width = client->width, height = client->height,
      depth = client->format.bitsPerPixel;
  client->updateRect.x = client->updateRect.y = 0;
  client->updateRect.w = width;
  client->updateRect.h = height;
  const int size = width * height * (depth / 8);
  VncClient *t = (VncClient *)rfbClientGetClientData(client, 0);
  t->width = width;
  t->height = height;
  t->frameBufferSize = size;
  if (t->frameBuffer) {
    delete[] t->frameBuffer;
  }
  t->frameBuffer = new uint8_t[size];
  client->frameBuffer = t->frameBuffer;
  memset(client->frameBuffer, '\0', size);

  switch (depth) {
  case 8:
    client->format.depth = 8;
    client->format.bitsPerPixel = 8;
    client->format.redShift = 0;
    client->format.greenShift = 3;
    client->format.blueShift = 6;
    client->format.redMax = 7;
    client->format.greenMax = 7;
    client->format.blueMax = 3;
    break;
  case 16:
    client->format.depth = 16;
    client->format.bitsPerPixel = 16;
    client->format.redShift = 11;
    client->format.greenShift = 5;
    client->format.blueShift = 0;
    client->format.redMax = 0x1f;
    client->format.greenMax = 0x3f;
    client->format.blueMax = 0x1f;
    break;
  case 32:
  default:
    client->format.depth = 24;
    client->format.bitsPerPixel = 32;
    client->format.redShift = 0;
    client->format.greenShift = 8;
    client->format.blueShift = 16;
    client->format.redMax = 0xff;
    client->format.greenMax = 0xff;
    client->format.blueMax = 0xff;
  }
  //    设置编码方式和压缩等级（默认）
  //    client->appData.encodingsString = "copyrect zrle ultra zlib hextile
  //    corre rre raw"; client->appData.compressLevel = 3;
  //    client->appData.qualityLevel = 5;

  SetFormatAndEncodings(client);

  JNIEnv *env;
  if (t->javaVM->AttachCurrentThread(&env, NULL) == JNI_OK) {
    jobject obj = t->javaObj;
    jclass cls = env->GetObjectClass(obj);
    jmethodID jmid = env->GetMethodID(cls, "imageResize", "(JII)V");

    if (jmid) {
      // 创建一个字节数组并填充数据
      env->CallVoidMethod(obj, jmid, t->id, t->width, t->height);
    }
    t->javaVM->DetachCurrentThread();
  }

  return TRUE;
}

static void update(rfbClient *cl, int x, int y, int w, int h) {
  //  __android_log_print(ANDROID_LOG_DEBUG, "libvncviewer_flutter",
  //                      "update: x:%d y:%d w:%d h:%d", x, y, w, h);

  VncClient *t = (VncClient *)rfbClientGetClientData(cl, 0);

  JNIEnv *env;
  if (t->javaVM->AttachCurrentThread(&env, NULL) != JNI_OK) {
    return;
  }
  //获取用于绘制的NativeWindow
  ANativeWindow *a_native_window =
      ANativeWindow_fromSurface(env, t->surfaceObj);

  //设置NativeWindow绘制的缓冲区
  ANativeWindow_setBuffersGeometry(a_native_window, t->width, t->height,
                                   WINDOW_FORMAT_RGBX_8888);

  //绘制时，用于接收的缓冲区
  ANativeWindow_Buffer a_native_window_buffer;

  //加锁然后进行渲染
  ANativeWindow_lock(a_native_window, &a_native_window_buffer, 0);
  uint8_t *data = t->frameBuffer;
  uint8_t *dst_data = static_cast<uint8_t *>(a_native_window_buffer.bits);
  if (a_native_window_buffer.stride == t->width) {
    memcpy(dst_data, data, t->frameBufferSize);
  } else {
    int linesize = t->width * 4;
    int padding = (a_native_window_buffer.stride - t->width) * 4;
    for (int i = 0; i < t->height; i++) {
      memcpy(dst_data, data, linesize);
      dst_data += linesize;
      data += linesize;
      dst_data += padding;
    }
  }
  //绘制完解锁
  ANativeWindow_unlockAndPost(a_native_window);

  //  jobject obj = t->javaObj;
  //  jclass cls = env->GetObjectClass(obj);
  //  jmethodID jmid = env->GetMethodID(cls, "imageData", "(J[BII)V");
  //
  //  if (jmid) {
  //    // 创建一个字节数组并填充数据
  //    jbyteArray byteArray = env->NewByteArray(t->frameBufferSize);
  //    jbyte *data = env->GetByteArrayElements(byteArray, nullptr);
  //    memcpy(data, t->frameBuffer, t->frameBufferSize);
  //    env->CallVoidMethod(obj, jmid, t->id, byteArray, t->width, t->height);
  //    env->ReleaseByteArrayElements(byteArray, data, 0);
  //  }
  t->javaVM->DetachCurrentThread();
}

static void kbd_leds(rfbClient *cl, int value, int pad) {
  /* note: pad is for future expansion 0=unused */
  fprintf(stderr, "Led State= 0x%02X\n", value);
  fflush(stderr);
}

static void text_chat(rfbClient *cl, int value, char *text) {
  switch (value) {
  case (int)rfbTextChatOpen:
    fprintf(stderr, "TextChat: We should open a textchat window!\n");
    TextChatOpen(cl);
    break;
  case (int)rfbTextChatClose:
    fprintf(stderr, "TextChat: We should close our window!\n");
    break;
  case (int)rfbTextChatFinished:
    fprintf(stderr, "TextChat: We should close our window!\n");
    break;
  default:
    fprintf(stderr, "TextChat: Received \"%s\"\n", text);
    break;
  }
  fflush(stderr);
}

static void got_selection(rfbClient *cl, const char *text, int len) {
  printf("received clipboard text '%s'\n", text);
}

static void cleanup(rfbClient *cl) {
  if (cl)
    rfbClientCleanup(cl);
}

VncClient::VncClient(string hostName, int port, string password, JavaVM *javaVM,
                     jobject javaObj, jobject surfaceObj) {
  this->hostName = hostName;
  this->port = port;
  this->password = password;
  this->javaVM = javaVM;
  this->javaObj = javaObj;
  this->surfaceObj = surfaceObj;
  auto now = std::chrono::system_clock::now();
  auto ms = std::chrono::time_point_cast<std::chrono::milliseconds>(now);
  auto value = ms.time_since_epoch().count();
  this->id = value;
}

void VncClient::initRfbClient() {
  cl = rfbGetClient(8, 3, 4);
  clientMap[id] = this;
  cl->MallocFrameBuffer = resize;
  cl->canHandleNewFBSize = TRUE;
  cl->GotFrameBufferUpdate = update;
  cl->HandleKeyboardLedState = kbd_leds;
  cl->HandleTextChat = text_chat;
  cl->GotXCutText = got_selection;
  cl->GetCredential = get_credential;
  rfbClientSetClientData(cl, 0, this);
  cl->GetPassword = ReadPassword;
  cl->listenPort = LISTEN_PORT_OFFSET;
  cl->listen6Port = LISTEN_PORT_OFFSET;
  cl->serverPort = port;
  char *host_name = (char *)malloc(sizeof(char) * hostName.size());
  strcpy(host_name, hostName.c_str());
  cl->serverHost = host_name;
}

void VncClient::connect() {
  thread t([=]() {
    if (!rfbInitClient(cl, 0, NULL)) {
      __android_log_print(ANDROID_LOG_DEBUG, "libvncviewer_flutter",
                          "VNC客户端初始化失败,请检查连接配置信息!");
      sendErrorMsg("VNC客户端初始化失败,请检查连接配置信息!");
      return;
    }
    //      callback(id, 0, "rfb客户端初始化成功");
    while (running) {
      int i = WaitForMessage(cl, 500);
      if (i < 0) {
        cleanup(cl);
        break;
      }

      if (i)
        if (!HandleRFBServerMessage(cl)) {
          cleanup(cl);
          break;
        }
    }
  });
  t.detach();
}

void VncClient::close() {
  running = false;
  __android_log_print(ANDROID_LOG_DEBUG, "libvncviewer_flutter",
                      "VNC 客户端关闭");
  std::this_thread::sleep_for(std::chrono::milliseconds(100));
  if (cl->sock) {
    ::close(cl->sock);
  }
  std::this_thread::sleep_for(std::chrono::milliseconds(100));
  if (frameBuffer) {
    delete[] frameBuffer;
    frameBuffer = NULL;
  }
  clientMap.erase(id);
}

VncClient *VncClient::getVncClient(int64_t id) { return clientMap[id]; }

void VncClient::sendPointer(int x, int y, int buttonMask) {
  SendPointerEvent(cl, x, y, buttonMask);
}

void VncClient::sendKeyEvent(int key, bool down) {
    SendKeyEvent(cl, key, down);
}

void VncClient::sendErrorMsg(string msg) {
  if (running && javaObj) {
    JNIEnv *env;
    if (javaVM->AttachCurrentThread(&env, NULL) == JNI_OK) {
      jclass cls = env->GetObjectClass(javaObj);
      jstring msgStr = env->NewStringUTF(msg.c_str());
      jmethodID jmid =
          env->GetMethodID(cls, "onError", "(JILjava/lang/String;)V");

      if (jmid) {
        env->CallVoidMethod(javaObj, jmid, id, 0, msgStr);
      }
      javaVM->DetachCurrentThread();
    }
  }
}
