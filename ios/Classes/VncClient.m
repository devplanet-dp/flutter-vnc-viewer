//
//  VncClient.m
//  libvncviewer_flutter
//
//  Created by 杨钊 on 2024/1/23.
//

#import "VncClient.h"
#include <rfb/rfbclient.h>
@interface VncClient()

@property(nonatomic,strong) NSString* hostName;

@property(nonatomic) int port;

@property(nonatomic,strong) NSString* password;

@property(nonatomic) rfbClient* cl;

@property(nonatomic,strong) GLRender* glRender;

@property uint8_t* frameBuffer;

@property int frameBufferSize;

@property int width;

@property int height;

@property bool running;

@property int64_t id;

@property ImageResizeCallBack imageResizeCallBack;

@property FrameCallBack frameCallBack;

@property InfoCallBack infoCallBack;

@end

static NSMutableDictionary *clientDictionary = nil;

static char *ReadPassword(rfbClient *cl) {
    int64_t* clientId = (int64_t *)rfbClientGetClientData(cl, 0);
    VncClient* client = [clientDictionary objectForKey:@(*clientId)];
    int size = client.password.length;
    char *password = (char *)malloc(size);
    memset(password, 0, size);
    memcpy(password, [client.password UTF8String], size);
    return password;
}

static void update(rfbClient *cl, int x, int y, int w, int h) {
    int64_t* clientId = (int64_t *)rfbClientGetClientData(cl, 0);
    VncClient* client = [clientDictionary objectForKey:@(*clientId)];
    [client.glRender refreshPixelBuffer:cl->frameBuffer];
    if(client.frameCallBack){
        client.frameCallBack(cl->frameBuffer,w,h);
    }
    
}

static rfbBool resize(rfbClient *cl) {
    int width = cl->width, height = cl->height,
    depth = cl->format.bitsPerPixel;
    cl->updateRect.x = cl->updateRect.y = 0;
    cl->updateRect.w = width;
    cl->updateRect.h = height;
    const int size = width * height * (depth / 8);
    int64_t* clientId = (int64_t *)rfbClientGetClientData(cl, 0);
    VncClient* client = [clientDictionary objectForKey:@(*clientId)];
    client.width = width;
    client.height = height;
    client.frameBufferSize = size;
    if(client.frameBuffer){
        free(client.frameBuffer);
    }
    client.frameBuffer = malloc(size);
    cl->frameBuffer =client.frameBuffer;
    memset(client.frameBuffer, 0, size);
    if(client.imageResizeCallBack){
        client.imageResizeCallBack(width,height);
    }
    
    switch (depth) {
        case 8:
            cl->format.depth = 8;
            cl->format.bitsPerPixel = 8;
            cl->format.redShift = 0;
            cl->format.greenShift = 3;
            cl->format.blueShift = 6;
            cl->format.redMax = 7;
            cl->format.greenMax = 7;
            cl->format.blueMax = 3;
            break;
        case 16:
            cl->format.depth = 16;
            cl->format.bitsPerPixel = 16;
            cl->format.redShift = 11;
            cl->format.greenShift = 5;
            cl->format.blueShift = 0;
            cl->format.redMax = 0x1f;
            cl->format.greenMax = 0x3f;
            cl->format.blueMax = 0x1f;
            break;
        case 32:
        default:
            cl->format.depth = 24;
            cl->format.bitsPerPixel = 32;
            cl->format.redShift = 0;
            cl->format.greenShift = 8;
            cl->format.blueShift = 16;
            cl->format.redMax = 0xff;
            cl->format.greenMax = 0xff;
            cl->format.blueMax = 0xff;
    }
    //  cl->appData.encodingsString = "copyrect zlib hextile raw";
    //  cl->appData.compressLevel = 0;
    //  cl->appData.qualityLevel = 9;
    
    //  cl->appData.encodingsString =
    //      "copyrect tight zrle ultra zlib hextile corre rre raw";
    //  cl->appData.compressLevel = 5;
    //  cl->appData.qualityLevel = 7;
    
    cl->appData.encodingsString =
    "copyrect zrle ultra zlib hextile corre rre raw";
    cl->appData.compressLevel = 9;
    cl->appData.qualityLevel = 1;
    
    SetFormatAndEncodings(cl);
    [client.glRender createCVBufferWithWidth:width withHeight:height];
    update(cl, 0, 0, width, height);
    return true;
}


static void kbd_leds(rfbClient *cl, int value, int pad) {
    /* note: pad is for future expansion 0=unused */
    fprintf(stderr, "Led State= 0x%02X\n", value);
    fflush(stderr);
}

static void text_chat(rfbClient *cl, int value, char *text) {
    switch (value) {
        case (int)rfbTextChatOpen:
            fprintf(stderr, "TextChat: We should open a textchat window!\n");
            TextChatOpen(cl);
            break;
        case (int)rfbTextChatClose:
            fprintf(stderr, "TextChat: We should close our window!\n");
            break;
        case (int)rfbTextChatFinished:
            fprintf(stderr, "TextChat: We should close our window!\n");
            break;
        default:
            fprintf(stderr, "TextChat: Received \"%s\"\n", text);
            break;
    }
    fflush(stderr);
}

static void got_selection(rfbClient *cl, const char *text, int len) {
    printf("received clipboard text '%s'\n", text);
}

static void cleanup(rfbClient *cl) {
    if (cl) {
        rfbClientCleanup(cl);
    }
}

@implementation VncClient


- (instancetype)initWith:(NSString*)hostName andPort:(int)port andPassword:(NSString*)password{
    self = [super init];
    if (self) {
        self.hostName=hostName;
        self.port=port;
        self.password=password;
        self.running=true;
        self.glRender=[[GLRender alloc] init];
        struct timeval te;
        gettimeofday(&te, NULL);
        int64_t milliseconds = te.tv_sec * 1000LL + te.tv_usec / 1000;
        self.id=milliseconds;
    }
    if(!clientDictionary){
        clientDictionary = [[NSMutableDictionary alloc]init];
    }
    
    return self;
}

-(void)initRfbClient{
    self.cl = rfbGetClient(8, 3, 4);
    self.cl->MallocFrameBuffer = resize;
    self.cl->canHandleNewFBSize = TRUE;
    self.cl->GotFrameBufferUpdate = update;
    self.cl->HandleKeyboardLedState = kbd_leds;
    self.cl->HandleTextChat = text_chat;
    // self.cl->GotXCutText = got_selection;
    rfbClientSetClientData(self.cl, 0,&_id);
    [clientDictionary setObject:self forKey:@(self.id)];
    self.cl->GetPassword = ReadPassword;
    self.cl->listenPort = LISTEN_PORT_OFFSET;
    self.cl->listen6Port = LISTEN_PORT_OFFSET;
    self.cl->serverPort = self.port;
    char *host_name = (char *)malloc(sizeof(char) * self.hostName.length);
    strcpy(host_name, [self.hostName UTF8String]);
    self.cl->serverHost = host_name;
}

-(void)connect{
    
    dispatch_queue_global_t global = dispatch_get_global_queue
    (DISPATCH_QUEUE_PRIORITY_DEFAULT,0);
    
    dispatch_async(global, ^{
        if (!rfbInitClient(self.cl, 0, NULL)) {
            self.running=false;
            [self sendErrorMsg:@"VNC客户端初始化失败,请检查连接配置信息!"];
            return;
        }
        //      callback(id, 0, "rfb客户端初始化成功");
        self.running=true;
        while (self.running) {
            int i = WaitForMessage(self.cl, 500);
            if (i < 0) {
                cleanup(self.cl);
                break;
            }
            
            if (i)
                if (!HandleRFBServerMessage(self.cl)) {
                    cleanup(self.cl);
                    break;
                }
        }
    });
    
}

-(void)close{
    NSLog(@"VNC Client Closed");
    
    if (self.running && self.cl->GotFrameBufferUpdate) {
        close(self.cl->sock);
    }
    self.running = false;
    if (self.frameBuffer) {
        free(self.frameBuffer) ;
        self.frameBuffer = NULL;
    }
    [clientDictionary removeObjectForKey:@(self.id)];
    [self.glRender releaseGL];
}

-(void) sendErrorMsg:(NSString*) msg{
    if(self.infoCallBack){
        self.infoCallBack(self.id,1,@"onError",msg);
    }
}

-(void)registerImageResizeCallBack:(ImageResizeCallBack)callback{
    self.imageResizeCallBack=callback;
}

-(void)registerFrameCallBack:(FrameCallBack)frameCallBack{
    self.frameCallBack=frameCallBack;
}

-(void)registerInfoCallBack:(InfoCallBack)infoCallBack{
    self.infoCallBack=infoCallBack;
}

-(void)sendPointer:(int)x andY:(int)y  andButtonMask:(int)buttonMask{
    SendPointerEvent(self.cl, x, y, buttonMask);
}

-(void)sendKey:(int)key andDown:(bool)down{
    SendKeyEvent(self.cl, key, down);
}

+(VncClient*) getVncClient:(int64_t)id{
    return [clientDictionary objectForKey:@(id)];
}

-(int64_t)getClientId{
    return self.id;
}

-(GLRender*)getGLRender{
    return self.glRender;
}

@end
