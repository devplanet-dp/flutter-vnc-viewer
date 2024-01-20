#include <jni.h>

#include <string>

#include "vncclient.h"

// JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved) {
//   JNIEnv *env = NULL;
//   //获取JNI_VERSION版本
//   if (vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK)
//   {
//     return -1;
//   }
//   java_vm = vm;

//  //返回jni 的版本
//  return JNI_VERSION_1_6;
//}

extern "C" JNIEXPORT void JNICALL
Java_com_libvncviewer_flutter_nativelib_VncClient_closeRfbClient(
    JNIEnv *env, jobject thiz, jlong client_id) {
  auto client = VncClient::getVncClient(client_id);
  client->close();

  jclass cls = env->GetObjectClass(client->javaObj);
  jmethodID jmid = env->GetMethodID(cls, "onClosed", "(J)V");
  if (jmid) {
    env->CallVoidMethod(client->javaObj, jmid, client->id);
  }
  env->DeleteGlobalRef(client->javaObj);
  env->DeleteGlobalRef(client->surfaceObj);
  //  delete client;
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_libvncviewer_flutter_nativelib_VncClient_rfbInitClient(
    JNIEnv *env, jobject thiz, jstring host_name, jint port, jstring password,
    jobject surface, jobject client_call_back) {
  const char *hostname = env->GetStringUTFChars(host_name, NULL);
  const char *pwd = env->GetStringUTFChars(password, NULL);
  JavaVM *jvm;
  env->GetJavaVM(&jvm);
  VncClient *client = new VncClient(string(hostname), port, string(pwd), jvm,
                                    env->NewGlobalRef(client_call_back),
                                    env->NewGlobalRef(surface));
  client->initRfbClient();
  //  jclass cls = env->GetObjectClass(thiz);
  //  jmethodID jmid = env->GetMethodID(cls, "onRfbInitSuccessCallBack",
  //  "(J)V"); if (jmid) {
  //    env->CallVoidMethod(thiz, jmid, client->id);
  //  }
  env->ReleaseStringUTFChars(host_name, hostname);
  env->ReleaseStringUTFChars(password, pwd);
  return client->id;
}
extern "C" JNIEXPORT void JNICALL
Java_com_libvncviewer_flutter_nativelib_VncClient_startRfbClient(
    JNIEnv *env, jobject thiz, jlong client_id) {
  VncClient::getVncClient(client_id)->connect();
}
extern "C" JNIEXPORT void JNICALL
Java_com_libvncviewer_flutter_nativelib_VncClient_sendPointer(
    JNIEnv *env, jobject thiz, jlong client_id, jint x, jint y, jint mask) {
  auto client = VncClient::getVncClient(client_id);
  if (client) {
    client->sendPointer(x, y, mask);
  }
}
