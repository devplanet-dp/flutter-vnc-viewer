import 'libvncviewer_flutter_platform_interface.dart';

class LibvncviewerFlutter {
  Future<String?> getPlatformVersion() {
    return LibvncviewerFlutterPlatform.instance.getPlatformVersion();
  }

  Future<String?> initVncClient(String hostName, int port, String password) {
    return LibvncviewerFlutterPlatform.instance
        .initVncClient(hostName, port, password);
  }

  void closeVncClient(int clientId) {
    return LibvncviewerFlutterPlatform.instance.closeVncClient(clientId);
  }

  void startVncClient(int clientId) {
    return LibvncviewerFlutterPlatform.instance.startVncClient(clientId);
  }

  void sendPointer(int clientId, int x, int y, int mask) {
    return LibvncviewerFlutterPlatform.instance
        .sendPointer(clientId, x, y, mask);
  }
}
