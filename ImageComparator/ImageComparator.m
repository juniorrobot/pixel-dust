//
//  ImageComparator.m
//
//  Created by Kain Osterholt on 10/27/18.
//  Copyright © 2018 Kain Osterholt. All rights reserved.
//

#import "ImageComparator.h"

#define DEBUG_GL_ERRORS

float quadVertices[] = {
    // positions   // texCoords
    -1.0f,  1.0f,  0.0f, 1.0f,
    -1.0f, -1.0f,  0.0f, 0.0f,
    1.0f, -1.0f,  1.0f, 0.0f,

    -1.0f,  1.0f,  0.0f, 1.0f,
    1.0f, -1.0f,  1.0f, 0.0f,
    1.0f,  1.0f,  1.0f, 1.0f
};

float pointVert[] = {
    // position
    0.0f, 0.0f
};

@implementation ImageComparator

@synthesize image1Width = _image1Width, image1Height = _image1Height;
@synthesize image2Width = _image2Width, image2Height = _image2Height;

-(id)initWithImages:(UIImage*)image1 image2:(UIImage*)image2;
{
    self = [super init];
    if(self != nil)
    {
        [self initializeResources];
        [self setImages:image1 image2:image2];
    }

    return self;
}

-(void)initializeResources
{
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    [EAGLContext setCurrentContext:_context];
    glDisable(GL_DEPTH_TEST);

    // Create render target for 1x1 super sample compare
    glGenFramebuffers(1, &_compareRenderTarget);
    glGenTextures(1, &_compareRenderTargetTex);

    // Create render target for iamge wxh diff result
    glGenFramebuffers(1, &_diffRenderTarget);
    glGenTextures(1, &_diffRenderTargetTex);

    glGenTextures(1, &_image1Tex);
    glGenTextures(1, &_image2Tex);

    glGenVertexArrays(1, &_quadVAO);
    glGenBuffers(1, &_quadVBO);
    glBindVertexArray(_quadVAO);
    glBindBuffer(GL_ARRAY_BUFFER, _quadVBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), &quadVertices, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));

    // VAO for a point in the center of the viewport
    glGenVertexArrays(1, &_pointVAO);
    glGenBuffers(1, &_pointVBO);
    glBindVertexArray(_pointVAO);
    glBindBuffer(GL_ARRAY_BUFFER, _pointVBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(pointVert), &pointVert, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), (void*)0);

    _compareVtxShader = [self compileShader:@"super_sample_compare" withType:GL_VERTEX_SHADER];
    _compareFrgShader = [self compileShader:@"super_sample_compare" withType:GL_FRAGMENT_SHADER];
    _compareProgram = [self createProgramWithShaders:_compareVtxShader fragmentShader:_compareFrgShader];

    _diffVtxShader = [self compileShader:@"diff" withType:GL_VERTEX_SHADER];
    _diffFrgShader = [self compileShader:@"diff" withType:GL_FRAGMENT_SHADER];
    _diffProgram = [self createProgramWithShaders:_diffVtxShader fragmentShader:_diffFrgShader];

    [self checkGLError:@"init"];
}

-(void)dealloc
{
    glDeleteBuffers(1, &_compareRenderTarget);
    glDeleteBuffers(1, &_diffRenderTarget);
    glDeleteBuffers(1, &_quadVAO);
    glDeleteBuffers(1, &_quadVBO);
    glDeleteBuffers(1, &_pointVAO);
    glDeleteBuffers(1, &_pointVBO);

    glDeleteTextures(1, &_compareRenderTargetTex);
    glDeleteTextures(1, &_diffRenderTargetTex);
    glDeleteTextures(1, &_image1Tex);
    glDeleteTextures(1, &_image2Tex);

    glDeleteShader(_compareVtxShader);
    glDeleteShader(_compareFrgShader);
    glDeleteShader(_compareProgram);

    glDeleteShader(_diffVtxShader);
    glDeleteShader(_diffFrgShader);
    glDeleteShader(_diffProgram);
}

-(void)checkGLError:(NSString*)tag
{
#ifdef DEBUG_GL_ERRORS
    GLenum err;
    while ((err = glGetError()) != GL_NO_ERROR) {
        NSLog(@"OpenGL error: %x in tag %@", err, tag);
    }
#endif
}

-(BOOL)compare
{
    [EAGLContext setCurrentContext:_context];

    glViewport(0, 0, 1, 1);
    
    // Bind fbo to draw into
    glBindFramebuffer(GL_FRAMEBUFFER, _compareRenderTarget);

    // Bind quad vtx array object
    glBindVertexArray(_pointVAO);

    // Bind textures
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _image2Tex);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _image1Tex);

    // Bind shaders and set variables
    glUseProgram(_compareProgram);
    int tex2Location = glGetUniformLocation(_compareProgram, "img2");
    glUniform1i(tex2Location, 1);

    int widthLoc = glGetUniformLocation(_compareProgram, "width");
    glUniform1f(widthLoc, (GLfloat)_image1Width);
    int heightLoc = glGetUniformLocation(_compareProgram, "height");
    glUniform1f(heightLoc, (GLfloat)_image1Height);

    // Draw some!
    glDrawArrays(GL_POINTS, 0, 1);

    [self checkGLError:@"compare"];

    BOOL same = [self getDiffFactor] == 0.0f;
    return same;
}

-(float)getDiffFactor
{
    glBindFramebuffer(GL_FRAMEBUFFER, _compareRenderTarget);

    GLubyte *data = (GLubyte*)malloc(4 * sizeof(GLubyte));

    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glReadPixels(0, 0, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, data);

    float factor = (float)(data[0] + data[1] + data[2]);
    printf("diff factor: %f\n", factor);
    [self checkGLError:@"getDiffFactor"];

    free(data);

    return factor;
}

-(UIImage*)getDiffImage
{
    GLsizei width  = _image1Width;
    GLsizei height = _image1Height;

    [EAGLContext setCurrentContext:_context];

    glViewport(0, 0, width, height);

    // Bind fbo to draw into
    glBindFramebuffer(GL_FRAMEBUFFER, _diffRenderTarget);

    // Bind quad vtx array object
    glBindVertexArray(_quadVAO);

    // Bind textures
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _image2Tex);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _image1Tex);

    // Bind shaders and set variables
    glUseProgram(_diffProgram);
    int tex2Location = glGetUniformLocation(_diffProgram, "img2");
    glUniform1i(tex2Location, 1);

    // Draw the entire quad (2 triangles)
    glDrawArrays(GL_TRIANGLES, 0, 6);

    NSInteger dataLength = width * height * 4;
    GLubyte *data = (GLubyte*)malloc(dataLength * sizeof(GLubyte));

    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, data);

    CGDataProviderRef ref = CGDataProviderCreateWithData(NULL, data, dataLength, NULL);
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGImageRef iref = CGImageCreate(width, height, 8, 32, width * 4, colorspace, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast,
                                    ref, NULL, true, kCGRenderingIntentDefault);

    UIGraphicsBeginImageContext(CGSizeMake(width, height));
    CGContextRef cgcontext = UIGraphicsGetCurrentContext();
    CGContextSetBlendMode(cgcontext, kCGBlendModeCopy);
    CGContextDrawImage(cgcontext, CGRectMake(0.0, 0.0, width, height), iref);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    free(data);
    CFRelease(ref);
    CFRelease(colorspace);
    CGImageRelease(iref);

    [self checkGLError:@"getDiffImage"];

    return image;
}

-(void)setImages:(UIImage*)image1 image2:(UIImage*)image2
{
    [EAGLContext setCurrentContext:_context];

    _image1Width = image1.size.width;
    _image1Height = image1.size.height;

    _image2Width = image2.size.width;
    _image2Height = image2.size.height;

    [self createDiffRenderTarget];
    [self createCompareRenderTarget];

    [self convert:image1 toTexture:_image1Tex];
    [self convert:image2 toTexture:_image2Tex];
}

-(void)convert:(UIImage*)image toTexture:(GLuint)texture
{
    GLsizei width  = _image1Width;
    GLsizei height = _image1Height;

    GLubyte* textureData = (GLubyte *)malloc(width * height * 4);

    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(textureData, width, height,
                                                 bitsPerComponent, bytesPerRow, CGImageGetColorSpace(image.CGImage),
                                                 kCGImageAlphaPremultipliedLast);

    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image.CGImage);
    CGContextRelease(context);

    glBindTexture(GL_TEXTURE_2D, texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, textureData);
    glBindTexture(GL_TEXTURE_2D, 0);

    free(textureData);

    [self checkGLError:@"convert"];
}

// Create the render target texture for the diff image
-(void)createDiffRenderTarget
{
    [EAGLContext setCurrentContext:_context];

    glBindFramebuffer(GL_FRAMEBUFFER, _diffRenderTarget);

    glBindTexture(GL_TEXTURE_2D, _diffRenderTargetTex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, _image1Width, _image1Height, 0, GL_RGB, GL_UNSIGNED_BYTE, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glBindTexture(GL_TEXTURE_2D, 0);

    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _diffRenderTargetTex, 0);

    NSAssert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE, @"Render target failed to initialize");
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    [self checkGLError:@"createRenderTarget"];
}

// Create a 1x1 target texture and FBO for the simple super-sampling compare
-(void)createCompareRenderTarget
{
    [EAGLContext setCurrentContext:_context];

    glBindFramebuffer(GL_FRAMEBUFFER, _compareRenderTarget);

    glBindTexture(GL_TEXTURE_2D, _compareRenderTargetTex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, 1, 1, 0, GL_RGB, GL_UNSIGNED_BYTE, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glBindTexture(GL_TEXTURE_2D, 0);

    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _compareRenderTargetTex, 0);

    NSAssert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE, @"Render target failed to initialize");
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    [self checkGLError:@"createCompareRenderTarget"];
}

- (GLuint)compileShader:(NSString*)shaderName withType:(GLenum)shaderType
{
    // Open the file
    NSString* shaderExtension = shaderType == GL_VERTEX_SHADER ? @"vtx" : @"frg";
    NSString* shaderPath = [[NSBundle mainBundle] pathForResource:shaderName
                                                           ofType:shaderExtension];
    NSError* error;
    NSString* shaderString = [NSString stringWithContentsOfFile:shaderPath
                                                       encoding:NSUTF8StringEncoding error:&error];
    if (!shaderString) {
        NSLog(@"Error loading shader: %@", error.localizedDescription);
        exit(1);
    }

    // Create OpenGL resource
    GLuint shaderHandle = glCreateShader(shaderType);

    // Set shader source string
    const char * shaderStringUTF8 = [shaderString UTF8String];
    GLint shaderStringLength = (GLint)[shaderString length];
    glShaderSource(shaderHandle, 1, &shaderStringUTF8, &shaderStringLength);

    // Compile
    glCompileShader(shaderHandle);

    // Check the compilation success/failure
    GLint compileSuccess;
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shaderHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"Error compiling shader: %@.%@", shaderName, shaderExtension);
        NSLog(@"%@", messageString);
        exit(1);
    }

    return shaderHandle;
}

- (GLuint)createProgramWithShaders:(GLuint)vertexShader fragmentShader:(GLuint)fragmentShader
{
    GLuint programHandle = glCreateProgram();
    glAttachShader(programHandle, vertexShader);
    glAttachShader(programHandle, fragmentShader);
    glLinkProgram(programHandle);

    GLint linkSuccess;
    glGetProgramiv(programHandle, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(programHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        NSAssert(false, @"Could not link shader program");
        return 0;
    }

    return programHandle;
}

@end