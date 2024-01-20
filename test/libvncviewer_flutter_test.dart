import 'package:flutter_test/flutter_test.dart';
import 'package:libvncviewer_flutter/libvncviewer_flutter.dart';
import 'package:libvncviewer_flutter/libvncviewer_flutter_platform_interface.dart';
import 'package:libvncviewer_flutter/libvncviewer_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockLibvncviewerFlutterPlatform
    with MockPlatformInterfaceMixin
    implements LibvncviewerFlutterPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final LibvncviewerFlutterPlatform initialPlatform = LibvncviewerFlutterPlatform.instance;

  test('$MethodChannelLibvncviewerFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelLibvncviewerFlutter>());
  });

  test('getPlatformVersion', () async {
    LibvncviewerFlutter libvncviewerFlutterPlugin = LibvncviewerFlutter();
    MockLibvncviewerFlutterPlatform fakePlatform = MockLibvncviewerFlutterPlatform();
    LibvncviewerFlutterPlatform.instance = fakePlatform;

    expect(await libvncviewerFlutterPlugin.getPlatformVersion(), '42');
  });
}
