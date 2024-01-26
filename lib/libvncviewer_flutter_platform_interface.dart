import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'libvncviewer_flutter_method_channel.dart';

abstract class LibvncviewerFlutterPlatform extends PlatformInterface {
  /// Constructs a LibvncviewerFlutterPlatform.
  LibvncviewerFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static LibvncviewerFlutterPlatform _instance =
      MethodChannelLibvncviewerFlutter();

  /// The default instance of [LibvncviewerFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelLibvncviewerFlutter].
  static LibvncviewerFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [LibvncviewerFlutterPlatform] when
  /// they register themselves.
  static set instance(LibvncviewerFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<int?> initVncClient(String hostName, int port, String password) {
    throw UnimplementedError('initVncClient() has not been implemented.');
  }

  void closeVncClient(int clientId) {
    throw UnimplementedError('closeVncClient() has not been implemented.');
  }

  void startVncClient(int clientId) {
    throw UnimplementedError('startVncClient() has not been implemented.');
  }

  void sendPointer(int clientId, int x, int y, int mask) {
    throw UnimplementedError('sendPointer() has not been implemented.');
  }
}
