#import "LibvncviewerFlutterPlugin.h"
#import "VncClient.h"
#import "GLRender.h"
static NSMutableDictionary *flutterEventSinkDictionary = nil;

static void rfbClientCallback(int64_t id,int code,NSString* flag,NSString* msg){
    dispatch_async(dispatch_get_main_queue(), ^{
        FlutterEventSink sink = [flutterEventSinkDictionary objectForKey:@(id)];
        if(sink){
            NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];
            [mutableDictionary setObject:flag forKey:@"flag"];
            [mutableDictionary setObject:@(code) forKey:@"code"];
            [mutableDictionary setObject:msg forKey:@"msg"];
            sink(mutableDictionary);
        }
    });
}

@interface LibvncviewerFlutterPlugin()<FlutterStreamHandler>

@property (nonatomic, strong) NSObject<FlutterTextureRegistry> *textures;

@property (nonatomic, strong) GLRender *glRender;

@end

@implementation LibvncviewerFlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    if(!flutterEventSinkDictionary){
        flutterEventSinkDictionary = [[NSMutableDictionary alloc]init];
    }
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"libvncviewer_flutter"
                                     binaryMessenger:[registrar messenger]];
    LibvncviewerFlutterPlugin* instance = [[LibvncviewerFlutterPlugin alloc] init];
    instance.textures=registrar.textures;
    [registrar addMethodCallDelegate:instance channel:channel];
    
    FlutterEventChannel* eventchannel = [FlutterEventChannel eventChannelWithName:@"libvncviewer_flutter_eventchannel" binaryMessenger:[registrar messenger]];
    [eventchannel setStreamHandler:instance];
}

#pragma mark - <FlutterStreamHandler>
- (FlutterError* _Nullable)onListenWithArguments:(id _Nullable)arguments
                                       eventSink:(FlutterEventSink)events {
    int64_t clientId=[[arguments objectForKey:@"clientId"] longLongValue];
    [flutterEventSinkDictionary setObject:events forKey:@(clientId)];
    events(@{@"flag":@"onReady"});
    return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments{
    int64_t clientId=[[arguments objectForKey:@"clientId"] longLongValue];
    [flutterEventSinkDictionary removeObjectForKey:@(clientId)];
    return nil;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    }
    if ([@"closeVncClient" isEqualToString:call.method]) {
        int64_t clientId=[[call.arguments objectForKey:@"clientId"] longLongValue];
        [[VncClient getVncClient:clientId] close];
    }
    if ([@"startVncClient" isEqualToString:call.method]) {
        int64_t clientId = [[call.arguments objectForKey:@"clientId"] longLongValue];
        [[VncClient getVncClient:clientId] connect];
    }
    if ([@"sendPointer" isEqualToString:call.method]) {
        int64_t clientId=[[call.arguments objectForKey:@"clientId"] longLongValue];
        int x=[[call.arguments objectForKey:@"x"] intValue];
        int y=[[call.arguments objectForKey:@"y"] intValue];
        int mask=[[call.arguments objectForKey:@"mask"] intValue];
        [[VncClient getVncClient:clientId] sendPointer:x andY:y andButtonMask:mask];
    }
    if ([@"sendKey" isEqualToString:call.method]) {
        int64_t clientId=[[call.arguments objectForKey:@"clientId"] longLongValue];
        int key=[[call.arguments objectForKey:@"key"] intValue];
        int down=[[call.arguments objectForKey:@"down"] intValue];
        [[VncClient getVncClient:clientId] sendKey:key andDown:down];
    }

    if ([@"initVncClient" isEqualToString:call.method]) {
        NSString* hostName=[call.arguments objectForKey:@"hostName"];
        int port=[[call.arguments objectForKey:@"port"] intValue];
        NSString* password=[call.arguments objectForKey:@"password"];
        VncClient* client = [[VncClient alloc] initWith:hostName andPort:port andPassword:password];
        
        __weak typeof(self) wself = self;
        
        [client registerInfoCallBack:rfbClientCallback];
        
        [client registerFrameCallBack:^(uint8_t*data,int w,int h){
            dispatch_async(dispatch_get_main_queue(), ^{
                [wself.textures textureFrameAvailable:client.textureId];
            });
        }];
        
        [client registerImageResizeCallBack:^(int width, int height) {
            client.textureId = [self.textures registerTexture:[client getGLRender]];
            dispatch_async(dispatch_get_main_queue(), ^{
                FlutterEventSink sink = [flutterEventSinkDictionary objectForKey:@(client.getClientId)];
                if(sink){
                    sink(@{@"flag":@"imageResize",@"width":@(width),@"height":@(height),@"textureId":@(client.textureId)});
                }
            });
            
        }];
        
        [client initRfbClient];
        
        result(@([client getClientId]));
    }
    //    result(FlutterMethodNotImplemented);
}

@end
