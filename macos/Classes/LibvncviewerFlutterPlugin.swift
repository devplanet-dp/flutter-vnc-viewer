import Cocoa
import FlutterMacOS

public class LibvncviewerFlutterPlugin: NSObject, FlutterPlugin,FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        let params = arguments as! NSDictionary
        let clientId = params.object(forKey: "clientId") as! Int64
        clientEventChannel[clientId]=events
        events(["flag":"onReady"])
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        let params = arguments as! NSDictionary
        let clientId = params.object(forKey: "clientId") as! Int64
        clientEventChannel.removeValue(forKey: clientId)
        return nil
    }
    
    
    private var textureRegistry: FlutterTextureRegistry?
    
    private var clientEventChannel:[Int64:FlutterEventSink] = [:]
    
    private var renderer: [Int64: MyTexture] = [:]
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "libvncviewer_flutter", binaryMessenger: registrar.messenger)
        let eventChannel = FlutterEventChannel(name: "libvncviewer_flutter_eventchannel", binaryMessenger: registrar.messenger)
        let instance = LibvncviewerFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
        instance.textureRegistry=registrar.textures
        
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
        case "initVncClient":
            let params = call.arguments as! NSDictionary
            let hostName = params.object(forKey: "hostName") as! String
            let port = params.object(forKey: "port") as! Int32
            let password = params.object(forKey: "password") as! String
            let client = VncClient(hostName, andPort: port, andPassword: password)
            client.registerImageResizeCallBack {  width, height in
                let myTexture = MyTexture(width: Int(width), height: Int(height))
                let textureId = self.textureRegistry?.register(myTexture) ?? -1
                client.textureId=textureId
                self.renderer[client.getId()]=myTexture
                let sink = self.clientEventChannel[client.getId()]!
                sink(["flag":"imageResize","width":width,"height":height,"textureId":textureId]);
            }
            client.registerInfoCallBack { clientId, code, flag, msg in
                let sink = self.clientEventChannel[clientId]!
                sink(["flag":flag,"code":code,"msg":msg]);
            }
            client.registerFrameCallBack { data, w, h in
                self.renderer[client.getId()]?.markFrameAvaliableRaw(buffer: data, len: Int(client.getFrameBufferSize()), width: Int(w), height: Int(h), stride_align: 1)
                self.textureRegistry?.textureFrameAvailable(client.textureId)
                
            }
            client.initRfbClient()
            result(client.getId())
        case "startVncClient":
            let params = call.arguments as! NSDictionary
            let clientId = params.object(forKey: "clientId") as! Int64
            VncClient.getVncClient(clientId).connect()
        case "closeVncClient":
            let params = call.arguments as! NSDictionary
            let clientId = params.object(forKey: "clientId") as! Int64
            let client = VncClient.getVncClient(clientId)
            client.close()
            self.textureRegistry?.unregisterTexture(client.textureId)
            self.renderer.removeValue(forKey: clientId)
        case "sendPointer":
            let params = call.arguments as! NSDictionary
            let clientId = params.object(forKey: "clientId") as! Int64
            let x = params.object(forKey: "x") as! Int32
            let y = params.object(forKey: "y") as! Int32
            let mask = params.object(forKey: "mask") as! Int32
            VncClient.getVncClient(clientId).sendPointer(x, andY: y, andButtonMask: mask)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
