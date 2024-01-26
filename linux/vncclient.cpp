#include "vncclient.h"

#include <thread>
map<int64_t, VncClient *> VncClient::clientMap;

static char *ReadPassword(rfbClient *client) {
  VncClient *vncClient = (VncClient *)rfbClientGetClientData(client, 0);
  char *password = (char *)malloc(vncClient->password.size());
  memset(password, 0, vncClient->password.size());
  memcpy(password, vncClient->password.c_str(), vncClient->password.size());
  return password;
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
  if (t->imageResizeCallBack) {
    t->imageResizeCallBack(width, height);
  }
  //  t->frameBuffer = new uint8_t[size];
  //  client->frameBuffer = t->frameBuffer;
  //  memset(client->frameBuffer, '\0', size);
  client->frameBuffer = get_my_texture_buffer(t->texture);

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
  //  client->appData.encodingsString = "copyrect zlib hextile raw";
  //  client->appData.compressLevel = 0;
  //  client->appData.qualityLevel = 9;

  //  client->appData.encodingsString =
  //      "copyrect tight zrle ultra zlib hextile corre rre raw";
  //  client->appData.compressLevel = 5;
  //  client->appData.qualityLevel = 7;

  client->appData.encodingsString =
      "copyrect zrle ultra zlib hextile corre rre raw";
  client->appData.compressLevel = 9;
  client->appData.qualityLevel = 1;

  SetFormatAndEncodings(client);

  return TRUE;
}

static void update(rfbClient *cl, int x, int y, int w, int h) {
  //  __android_log_print(ANDROID_LOG_DEBUG, "libvncviewer_flutter",
  //                      "update: x:%d y:%d w:%d h:%d", x, y, w, h);

  VncClient *t = (VncClient *)rfbClientGetClientData(cl, 0);
  for (int i = 0; i < t->frameBufferSize; i += 4) {
    cl->frameBuffer[i - 1] = 0xFF;
  }
  if (t->frameUpdateCallBack) {
    t->frameUpdateCallBack(cl->frameBuffer, w, h);
  }
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
  if (cl) rfbClientCleanup(cl);
}
VncClient::VncClient(string hostName, int port, string password) {
  this->hostName = hostName;
  this->port = port;
  this->password = password;
  auto now = std::chrono::system_clock::now();
  auto ms = std::chrono::time_point_cast<std::chrono::milliseconds>(now);
  auto value = ms.time_since_epoch().count();
  this->id = value;
  clientMap[id] = this;
}

void VncClient::release() {
  running = false;
  if (cl->GotFrameBufferUpdate) {
    close(cl->sock);
  }
  if (frameBuffer) {
    delete[] frameBuffer;
    frameBuffer = NULL;
  }
  clientMap.erase(id);
}

void VncClient::initRfbClient() {
  cl = rfbGetClient(8, 3, 4);
  cl->MallocFrameBuffer = resize;
  cl->canHandleNewFBSize = TRUE;
  cl->GotFrameBufferUpdate = update;
  cl->HandleKeyboardLedState = kbd_leds;
  cl->HandleTextChat = text_chat;
  cl->GotXCutText = got_selection;
  //  cl->GetCredential = get_credential;
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
      if (errorCallback) {
        errorCallback(id, 1, "", "VNC客户端初始化失败,请检查连接配置信息!");
      }
      return;
    }
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

void VncClient::registerErrorCallback(ErrorCallback callback) {
  this->errorCallback = callback;
}

void VncClient::sendPointer(int x, int y, int buttonMask) {
  SendPointerEvent(cl, x, y, buttonMask);
}

void VncClient::sendKey(int key, bool upOrDown) {}

VncClient *VncClient::getClient(int64_t id) { return clientMap[id]; }
