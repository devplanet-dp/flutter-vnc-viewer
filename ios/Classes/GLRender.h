//
//  GLRender.h
//  libvncviewer_flutter
//
//  Created by 杨钊 on 2024/1/21.
//

#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>
NS_ASSUME_NONNULL_BEGIN

@interface GLRender : NSObject<FlutterTexture>

- (instancetype)createCVBufferWithWidth:(int)w withHeight:(int)h;

- (void) refreshPixelBuffer:(uint8_t*)data;

- (void)releaseGL;

@end

NS_ASSUME_NONNULL_END
