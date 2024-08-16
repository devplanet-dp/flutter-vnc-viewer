import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:libvncviewer_flutter/VncViewerWidget.dart';
import 'package:libvncviewer_flutter/libvncviewer_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _libvncviewerFlutterPlugin = LibvncviewerFlutter();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion = await _libvncviewerFlutterPlugin.getPlatformVersion() ??
          'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: AppPage());
  }
}

class AppPage extends StatelessWidget {
  TextEditingController _hostNameEditingController = new TextEditingController()
    ..text = "185.221.36.9";

  TextEditingController _portEditingController = new TextEditingController()
    ..text = "52100";

  TextEditingController _passwordEditingController = new TextEditingController()
    ..text = "123456";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LibVncViewer example app'),
      ),
      body: Container(
        margin: EdgeInsets.all(10),
        child: Center(
          child: Column(
            children: [
              TextFormField(
                controller: _hostNameEditingController,
                decoration: const InputDecoration(
                  hintText: 'host name',
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _portEditingController,
                decoration: const InputDecoration(
                  hintText: 'port',
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordEditingController,
                decoration: const InputDecoration(
                  hintText: 'password',
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  return null;
                },
              ),
              Text(""),
              CupertinoButton.filled(
                onPressed: () {
                  String hostName = _hostNameEditingController.text;
                  String port = _portEditingController.text;
                  String password = _passwordEditingController.text;
                  Navigator.push(context, MaterialPageRoute(builder: (context) {
                    return VncViewerWidget(
                      hostName,
                      int.parse(port),
                      password,
                      onlyview: false,
                    );
                  }));
                },
                child: const Text('open vnc viewer'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
