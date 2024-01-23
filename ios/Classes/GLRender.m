//
//  GLRender.m
//  libvncviewer_flutter
//
//  Created by 杨钊 on 2024/1/21.
//

#import "GLRender.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <CoreVideo/CoreVideo.h>
#import <UIKit/UIKit.h>

static GLfloat vertices[] = {
    -1.0f,  1.0f, 0.0f,  // Top-left
    -1.0f, -1.0f, 0.0f,  // Bottom-left
    1.0f,  1.0f, 0.0f,  // Top-right
    1.0f, -1.0f, 0.0f  // Bottom-right
};

static GLfloat texCoords[] = {
    0.0f, 1.0f,  // Top-left
    0.0f, 0.0f,  // Bottom-left
    1.0f, 1.0f,   // Top-right
    1.0f, 0.0f  // Bottom-right
    
};

static unsigned int indices[] = {
    0, 2, 3,
    1, 4, 5
};

@implementation GLRender
{
    CVPixelBufferRef pixelBuffer;
    
    int width;
    
    int height;
    
    EAGLContext *_context;
    
    //    GLuint _program;
    
    // 表示一块帧缓冲区的地
    GLuint _frameBuffer;
    // 表示一块渲染缓冲区的地址
    GLuint _renderBuffer;
    
    CVOpenGLESTextureCacheRef _textureCache;
    
    CVOpenGLESTextureRef _textureRef;
    
    GLuint _texture;
    
    GLuint _program;
    
    int _lastUpdateTs;
    GLfloat _angle;
    
}

- (instancetype)init{
    if (self = [super init]) {
        [self initGL];
    }
    return self;
}


- (CVPixelBufferRef) copyPixelBuffer {
    CVBufferRetain(pixelBuffer);
    return pixelBuffer;
}

- (void)initGL {
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:_context];
}


- (void)createCVBufferWithWidth:(int)w withHeight:(int)h {
    width=w;
    height=h;
    
    //    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:_context];
    
    
    CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_textureCache);
    if (err) {
        return;
    }
    CFDictionaryRef empty;
    CFMutableDictionaryRef attrs;
    empty = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    
    CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, empty);
    CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA, attrs, &pixelBuffer);
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _textureCache, pixelBuffer, NULL, GL_TEXTURE_2D, GL_RGBA, width, height, GL_BGRA, GL_UNSIGNED_BYTE, 0, &_textureRef);
    CFRelease(empty);
    CFRelease(attrs);
    
    // 创建渲染buffer
    //    glGenRenderbuffers(1, &_renderBuffer);
    //    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    //    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, width, height);
    
    // 创建帧缓冲区
    glGenFramebuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    
    //    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _renderBuffer);
    
    // 将纹理附加到帧缓冲区上
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(_textureRef), 0);
    
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
    }
    
    [self loadShaders];
    
    
}

- (void)releaseGL {
    glDeleteFramebuffers(1, &_frameBuffer);
    if(pixelBuffer){
        CFRelease(pixelBuffer);
    }
    if(_textureCache){
        CFRelease(_textureCache);
    }
    if(_textureRef){
        CFRelease(_textureRef);
    }
}

- (void) refreshPixelBuffer:(uint8_t*)data{
    [EAGLContext setCurrentContext:_context];
    glClearColor(0.2, 0.2, 0.2, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glViewport(0, 0, width, height);
    
    _texture = CVOpenGLESTextureGetName(_textureRef);
    //    int activeTexture = GL_TEXTURE0+_texture;
    //    glActiveTexture(activeTexture);
    //    glBindTexture(CVOpenGLESTextureGetTarget(_textureRef), _texture);
    
    glUseProgram(_program);
    GLuint position = glGetAttribLocation(_program, "position");
    GLuint texcoord = glGetAttribLocation(_program, "texcoord");
    GLuint inputTexture = glGetUniformLocation(_program, "inputTexture");
    //
    glVertexAttribPointer(position, 3, GL_FLOAT, GL_FALSE, 0, vertices);
    glEnableVertexAttribArray(position);
    glVertexAttribPointer(texcoord, 2, GL_FLOAT, GL_FALSE, 0, texCoords);
    glEnableVertexAttribArray(texcoord);
    
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); // S方向上的贴图模式
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE); // T方向上的贴图模式
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    //    已经在着色器中处理alpha通道
    //    for (int i=0;i<width*height*4;i+=4) {
    //        if(i==0){
    //            continue;
    //        }
    //        data[i-1]=0xFF;
    //    }
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
    
    glUniform1i(inputTexture, _texture);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glFlush();
}

#pragma mark - shader compilation
- (BOOL)loadShaders
{
    
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    _program = glCreateProgram();
    
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"failed to compile vertex shader");
        return NO;
    }
    
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"failed to compile fragment shader");
        return NO;
    }
    
    glAttachShader(_program, vertShader);
    glAttachShader(_program, fragShader);
    
    if (![self linkProgram:_program]) {
        NSLog(@"failed to link program: %d", _program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        return NO;
    }
    
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
    NSLog(@"load shaders succ");
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar*)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"failed to load shader. type: %i", type);
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"program validate log : \n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

@end
