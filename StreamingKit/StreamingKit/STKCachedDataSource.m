//
//  STKCachedDataSource.m
//  StreamingKit
//
//  Created by bianchui on 2022/7/26.
//  Copyright © 2022 bianchui. All rights reserved.
//

#import "STKCachedDataSource.h"
#import <CommonCrypto/CommonDigest.h>
#import "STKAutoRecoveringHTTPDataSource.h"
#import "STKLocalFileDataSource.h"
#include <stdio.h>
#include <stdlib.h>

@interface STKCachedDataSource() {
    AudioFileTypeID audioFileTypeHint;
    STKLocalFileDataSource* fileSource;
    STKAutoRecoveringHTTPDataSource* httpSource;
    STKDataSource* usingDataSource;
    NSString* fullPath;
    NSString* metaPath;
    NSMutableDictionary* meta;
}
@end

@implementation STKCachedDataSource

+ (NSString*) readString:(NSString*)path {
    FILE* fp = fopen([path UTF8String], "rb");
    if (fp) {
        fseek(fp, 0, SEEK_END);
        uint64_t size = ftell(fp);
        fseek(fp, 0, SEEK_SET);
        char* buf = (char*)malloc(size);
        fread(buf, 1, size, fp);
        fclose(fp);
    }
    return nil;
}

-(instancetype) initWithUrl:(NSURL*)url cachePath:(NSString*)cachePath {
    if (self = [super init]) {
        NSString* md5 = [STKCachedDataSource Md5:[[url absoluteString] UTF8String]];
        NSString* extension = [[url path] pathExtension];
        audioFileTypeHint = [STKLocalFileDataSource audioFileTypeHintFromFileExtension:extension];
        fullPath = [cachePath stringByAppendingPathComponent:md5];
        metaPath = [fullPath stringByAppendingPathExtension:@"plist"];
        fullPath = [fullPath stringByAppendingPathExtension:extension];
        meta = [[NSMutableDictionary alloc] initWithContentsOfFile:metaPath];
        bool isValid = false;
        if (!meta) {
            meta = [[NSMutableDictionary alloc] init];
        } else {
            //checkMeta
            isValid = true;
        }
        
        if (isValid) {
            url = [NSURL URLWithString:fullPath];
            fileSource = [[STKLocalFileDataSource alloc] initWithFilePath:url.path];
            fileSource.delegate = self;

            usingDataSource = fileSource;
        } else {
            httpSource = [[STKAutoRecoveringHTTPDataSource alloc] initWithHTTPDataSource:[[STKHTTPDataSource alloc] initWithURL:url]];
            httpSource.delegate = self;

            usingDataSource = httpSource;
        }
    }
    return self;
}

+ (NSString*)Md5:(const char*)input {
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(input, (CC_LONG)strlen(input), digest); // This is the md5 call
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    return output;
}

-(AudioFileTypeID) audioFileTypeHint {
    NSLog(@"audioFileTypeHint");
    return audioFileTypeHint;
}

- (STKDataSource*)innerDataSource {
    NSLog(@"innerDataSource");
    return usingDataSource;
}

-(BOOL) registerForEvents:(NSRunLoop*)runLoop {
    NSLog(@"registerForEvents");
    return [super registerForEvents:runLoop];
}

-(void) unregisterForEvents {
    NSLog(@"unregisterForEvents");
    [super unregisterForEvents];
}

-(int) readIntoBuffer:(UInt8*)buffer withSize:(int)size {
    NSLog(@"readIntoBuffer");
    if (usingDataSource) {
        SInt64 start = usingDataSource.position;
        int ret = [usingDataSource readIntoBuffer:buffer withSize:size];
        if (usingDataSource == httpSource) {
            // cache for http
            
        }

        return ret;
    }
    return 0;
}

@end
