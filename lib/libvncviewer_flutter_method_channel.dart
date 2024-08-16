import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'libvncviewer_flutter_platform_interface.dart';

/// An implementation of [LibvncviewerFlutterPlatform] that uses method channels.
class MethodChannelLibvncviewerFlutter extends LibvncviewerFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('libvncviewer_flutter');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<int?> initVncClient(String hostName, int port, String password) async {
    final datas = await methodChannel.invokeMethod<int>('initVncClient',
        {"hostName": hostName, "port": port, "password": password});
    return datas;
  }

  @override
  void closeVncClient(int clientId) {
    methodChannel.invokeMethod('closeVncClient', {"clientId": clientId});
  }

  @override
  void startVncClient(int clientId) {
    methodChannel.invokeMethod('startVncClient', {"clientId": clientId});
  }

  @override
  void sendPointer(int clientId, int x, int y, int mask) {
    methodChannel.invokeMethod(
        'sendPointer', {"clientId": clientId, "x": x, "y": y, "mask": mask});
  }

  @override
  void sendKey(int clientId, int key, bool down) {
    methodChannel.invokeMethod(
        'sendKey', {"clientId": clientId, "key": key, "down": down});
  }
}
