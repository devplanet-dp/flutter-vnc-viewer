import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libvncviewer_flutter/libvncviewer_flutter.dart';

class VncViewerWidget extends StatefulWidget {
  String hostName;
  String password;
  int port;

  VncViewerWidget(this.hostName, this.port, this.password);

  @override
  State<StatefulWidget> createState() => _VncViewerWidgetState();
}

class _VncViewerWidgetState extends State<VncViewerWidget> {
  static const EventChannel _channel =
      const EventChannel('libvncviewer_flutter_eventchannel');

  StreamSubscription? _streamSubscription;

  StreamController<int> _streamController = StreamController();

  final _libvncviewerFlutterPlugin = LibvncviewerFlutter();

  int _imageWidth = 0;

  int _imageHeight = 0;

  double _width = 0;

  double _height = 0;

  int _clientId = 0;

  int _textureId = -1;

  double _scale = 1.0;

  int _buttonMask = 0;

  GlobalKey _vncViewKey = new GlobalKey();

  bool _showAppBar = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      // String datas = await _libvncviewerFlutterPlugin.initVncClient(
      //         "192.168.0.106", 5900, "123456") ??
      //     "";
      String datas = await _libvncviewerFlutterPlugin.initVncClient(
              widget.hostName, widget.port, widget.password) ??
          "";
      if (datas != "") {
        var data = jsonDecode(datas);
        _clientId = data["clientId"];
        _textureId = data["surfaceId"];
        print("_textureId is " + _textureId.toString());
        _streamSubscription = _channel
            .receiveBroadcastStream({"clientId": _clientId}).listen(
                (dynamic event) {
          String message = event;
          var data = jsonDecode(message);
          String flag = data["flag"];
          if (flag == "imageResize") {
            _imageWidth = data["width"];
            _imageHeight = data["height"];
            _streamController.add(1);
          }
          if (flag == "onReady") {
            print("start vnc client");
            _libvncviewerFlutterPlugin.startVncClient(_clientId);
          }
          if (flag == "onError") {
            String errMsg = data["msg"];
            showCupertinoModalPopup<void>(
              context: context,
              builder: (BuildContext context) {
                return CupertinoAlertDialog(
                  title: const Text('错误提示'),
                  content: Text(errMsg),
                  actions: <CupertinoDialogAction>[
                    CupertinoDialogAction(
                      isDestructiveAction: true,
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: const Text('关闭'),
                    ),
                  ],
                );
              },
            );
          }
        }, onError: (dynamic error) {
          print('Received error: ${error.message}');
        }, cancelOnError: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _width = MediaQuery.of(context).size.width;
    _height = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: PreferredSize(preferredSize: Size.zero, child: AppBar()),
      body: StreamBuilder<int>(
          initialData: _textureId,
          stream: _streamController.stream,
          builder: (context, async) {
            var appBar = AppBar(
              automaticallyImplyLeading: false,
              iconTheme: const IconThemeData(
                color: Colors.white, // 设置返回箭头颜色为白色
              ),
              leading: IconButton(
                enableFeedback: true,
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              backgroundColor: Color.fromARGB(60, 0, 0, 0),
              toolbarTextStyle: TextStyle(color: Colors.white),
              actions: [
                IconButton(
                    icon: const Icon(Icons.fullscreen),
                    onPressed: () {
                      double w = MediaQuery.of(context).size.width;
                      double h = MediaQuery.of(context).size.height;
                      if (w < h) {
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.landscapeLeft,
                          DeviceOrientation.landscapeRight
                        ]);
                      } else {
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitUp,
                          DeviceOrientation.portraitDown
                        ]);
                      }
                    })
              ],
            );
            if (async.data == -1) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    CupertinoActivityIndicator(
                      radius: 15,
                    ),
                    SizedBox(height: 10),
                    Text('正在连接'),
                  ],
                ),
              );
            }
            if (_imageWidth > 0 || _width < _imageWidth) {
              _scale = _width / _imageWidth;
              _height = _imageHeight * _scale;
            }
            return Container(
              color: Colors.white,
              child: GestureDetector(
                onTap: () {
                  _showAppBar = !_showAppBar;
                  setState(() {});
                  if (_showAppBar) {
                    Future.delayed(Duration(seconds: 2), () {
                      _showAppBar = false;
                      setState(() {});
                    });
                  }
                },
                child: InteractiveViewer(
                    scaleEnabled: true,
                    maxScale: 10,
                    minScale: 0.5,
                    child: Center(
                      child: Container(
                        width: _width,
                        height: _height,
                        child: GestureDetector(
                          // behavior: HitTestBehavior.opaque,
                          onTapDown: (details) {
                            _buttonMask = 0x01;
                            var localPosition = details.localPosition;
                            int x = (localPosition.dx / _scale).toInt();
                            int y = (localPosition.dy / _scale).toInt();
                            _libvncviewerFlutterPlugin.sendPointer(
                                _clientId, x, y, _buttonMask);
                          },
                          onTapUp: (details) {
                            _buttonMask &= 0xfe;
                            var localPosition = details.localPosition;
                            _libvncviewerFlutterPlugin.sendPointer(
                                _clientId,
                                (localPosition.dx / _scale).toInt(),
                                (localPosition.dy / _scale).toInt(),
                                _buttonMask);
                          },
                          child: Texture(
                            textureId: _textureId,
                            key: _vncViewKey,
                          ),
                        ),
                      ),
                    )),
              ),
            );
          }),
    );
  }

  @override
  void dispose() {
    super.dispose();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    _streamSubscription!.cancel();
    _libvncviewerFlutterPlugin.closeVncClient(_clientId);
  }
}
