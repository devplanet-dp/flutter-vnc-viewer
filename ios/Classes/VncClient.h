//
//  VncClient.h
//  libvncviewer_flutter
//
//  Created by 杨钊 on 2024/1/23.
//

#import <Foundation/Foundation.h>
#import "GLRender.h"
NS_ASSUME_NONNULL_BEGIN

typedef void(*InfoCallBack)(int64_t id,int code,NSString* flag,NSString* msg);

typedef void(^FrameCallBack)(uint8_t* data,int width,int height);

typedef void(^ImageResizeCallBack)(int width,int height);

@interface VncClient : NSObject

@property int64_t textureId;

- (instancetype)initWith:(NSString*)hostName andPort:(int)port andPassword:(NSString*)password;

-(void)initRfbClient;

-(void)connect;

-(void)close;

-(void)registerImageResizeCallBack:(ImageResizeCallBack)callback;

-(void)registerFrameCallBack:(FrameCallBack)frameCallBack;

-(void)registerInfoCallBack:(InfoCallBack)infoCallBack;

-(void)sendPointer:(int)x andY:(int)y andButtonMask:(int)buttonMask;

-(void)SendKeyEvent:(int)key andDown:(bool)down;

-(void)setTextureId:(int64_t)textureId;

+(VncClient*) getVncClient:(int64_t)id;

-(int64_t)getClientId;

-(GLRender*)getGLRender;


@end

NS_ASSUME_NONNULL_END
