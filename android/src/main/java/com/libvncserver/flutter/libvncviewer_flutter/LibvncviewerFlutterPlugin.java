package com.libvncserver.flutter.libvncviewer_flutter;

import android.graphics.SurfaceTexture;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.view.Surface;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;

import com.libvncviewer.flutter.nativelib.RfbClientCallBack;
import com.libvncviewer.flutter.nativelib.VncClient;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.view.TextureRegistry;

/**
 * LibvncviewerFlutterPlugin
 */
public class LibvncviewerFlutterPlugin implements FlutterPlugin, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private MethodChannel channel;

    private EventChannel eventChannel;

    private Map<Long,EventChannel.EventSink> eventSinkMap = new HashMap<>();

    private Integer removeSinkLock = 0;

    private Handler handler = new Handler(Looper.getMainLooper());

    private FlutterPluginBinding flutterPluginBinding;

    @RequiresApi(api = Build.VERSION_CODES.FROYO)
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        this.flutterPluginBinding=flutterPluginBinding;
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "libvncviewer_flutter");
        channel.setMethodCallHandler(this);
        eventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), "libvncviewer_flutter_eventchannel");
        eventChannel.setStreamHandler(new EventChannel.StreamHandler() {

            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                if (arguments instanceof HashMap){
                    Map args = (Map) arguments;
                    String clientId = args.get("clientId").toString();
                    eventSinkMap.put(Long.valueOf(clientId),events);
                    JSONObject jsonObject = new JSONObject();
                    try {
                        jsonObject.put("flag","onReady");
                        events.success(jsonObject.toString());
                    } catch (JSONException e) {
                        throw new RuntimeException(e);
                    }
                }
            }

            @Override
            public void onCancel(Object arguments) {
                if (arguments instanceof HashMap){
                    Map args = (Map) arguments;
                    String clientId = args.get("clientId").toString();
                    synchronized (removeSinkLock) {
                        eventSinkMap.remove(Long.valueOf(clientId));
                    }
                }

            }
        });
    }

    @RequiresApi(api = Build.VERSION_CODES.ICE_CREAM_SANDWICH)
    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        if (call.method.equals("getPlatformVersion")) {
            result.success("Android " + android.os.Build.VERSION.RELEASE);
        }
        if (call.method.equals("closeVncClient")) {
            long clientId = call.argument("clientId");
            new VncClient().closeRfbClient(clientId);
        }
        if (call.method.equals("startVncClient")) {
            long clientId = call.argument("clientId");
            new VncClient().startRfbClient(clientId);
        }
        if (call.method.equals("sendPointer")) {
            long clientId = call.argument("clientId");
            int x = call.argument("x");
            int y = call.argument("y");
            int mask = call.argument("mask");
            new VncClient().sendPointer(clientId,x,y,mask);
        }
        if (call.method.equals("initVncClient")) {
            TextureRegistry.SurfaceTextureEntry surfaceTextureEntry = flutterPluginBinding.getTextureRegistry().createSurfaceTexture();
            SurfaceTexture surfaceTexture = surfaceTextureEntry.surfaceTexture();
            Surface surface = new Surface(surfaceTexture);
            String hostName = call.argument("hostName");
            int port = call.argument("port");
            String password = call.argument("password");
            long clientId = new VncClient().rfbInitClient(hostName, port, password, surface, new RfbClientCallBack() {
                @Override
                public void onError(long clientId, int code, String msg) {
                    JSONObject jsonObject = new JSONObject();
                    try {
                        jsonObject.put("flag","onError");
                        jsonObject.put("code",code);
                        jsonObject.put("msg",msg);
                        handler.post(()->{
                            EventChannel.EventSink sink = eventSinkMap.get(clientId);
                            if (sink != null) {
                                sink.success(jsonObject.toString());
                            }
                        });
                    } catch (JSONException e) {
                        throw new RuntimeException(e);
                    }
                }

                @Override
                public void onClosed(long clientId) {
                    surfaceTexture.release();
                    surface.release();
                    surfaceTextureEntry.release();
                }

                @Override
                public void onConnectSuccess(long clientId, int width, int height) {
                    JSONObject jsonObject = new JSONObject();
                    try {
                        jsonObject.put("flag","onConnectSuccess");
                        jsonObject.put("width",width);
                        jsonObject.put("height",height);
                        handler.post(()->{
                            EventChannel.EventSink sink = eventSinkMap.get(clientId);
                            if (sink != null) {
                                sink.success(jsonObject.toString());
                            }
                        });
                    } catch (JSONException e) {
                        throw new RuntimeException(e);
                    }
                }

                @Override
                public void imageData(long clientId, byte[] datas, int width, int height) {

                }

                @Override
                public void imageResize(long clientId, int width, int height) {
                    JSONObject jsonObject = new JSONObject();
                    try {
                        jsonObject.put("flag","imageResize");
                        jsonObject.put("width",width);
                        jsonObject.put("height",height);
                        handler.post(()->{
                            Toast toast=Toast.makeText(flutterPluginBinding.getApplicationContext(), "连接成功", Toast.LENGTH_SHORT);
                            toast.show();
                            EventChannel.EventSink sink = eventSinkMap.get(clientId);
                            if (sink != null) {
                                sink.success(jsonObject.toString());
                            }
                        });
                    } catch (JSONException e) {
                        throw new RuntimeException(e);
                    }
                }
            });
            long surfaceId = surfaceTextureEntry.id();
            JSONObject jsonObject = new JSONObject();
            try {
                jsonObject.put("clientId",clientId);
                jsonObject.put("surfaceId",surfaceId);
                result.success(jsonObject.toString());
            } catch (JSONException e) {
                throw new RuntimeException(e);
            }
        }

//    result.notImplemented();
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }

}
