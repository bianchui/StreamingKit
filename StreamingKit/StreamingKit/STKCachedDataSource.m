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

#define BUFFER_SIZE 0// (256 * 1024)
#define MAX_CACHE (64 * 1024 * 1024)

static const NSString* kKeyDone = @"done";
static const NSString* kKeyLength = @"length";
static const NSString* kKeyChunks = @"chunks";

@interface STKCachedDataSource() {
    AudioFileTypeID audioFileTypeHint;
    STKLocalFileDataSource* fileSource;
    STKAutoRecoveringHTTPDataSource* httpSource;
    STKDataSource* usingDataSource;
    NSString* fullPath;
    NSString* metaPath;
    NSMutableDictionary* meta;
#if BUFFER_SIZE
    char* buffer; // buffer for data flush
    uint32_t bufOff; // buffer data offset in file
    uint32_t bufSize; // buffer using size
#endif//BUFFER_SIZE
}

@end

@implementation STKCachedDataSource

static bool writeBinary(const char* path, uint32_t off, const void* data, uint32_t size) {
    FILE* fp = fopen(path, "rb+");
    if (!fp && errno == ENOENT) {
        fp = fopen(path, "wb+");
    }
    if (fp) {
        fseek(fp, off, SEEK_SET);
        fwrite(data, 1, size, fp);
        fclose(fp);
        return true;
    } else {
        return false;
    }
}

static bool addChunk(NSMutableDictionary* meta, uint32_t off, uint32_t size, uint32_t total) {
}

-(instancetype) initWithUrl:(NSURL*)url cachePath:(NSString*)cachePath {
    if (self = [super init]) {
        NSString* md5 = [STKCachedDataSource Md5:[[url absoluteString] UTF8String]];
        NSString* extension = [[url path] pathExtension];
        audioFileTypeHint = [STKLocalFileDataSource audioFileTypeHintFromFileExtension:extension];
        fullPath = [cachePath stringByAppendingPathComponent:md5];
        metaPath = [fullPath stringByAppendingPathExtension:@"plist"];
        fullPath = [fullPath stringByAppendingPathExtension:extension];
        meta = [NSMutableDictionary dictionaryWithContentsOfFile:metaPath];
        bool isDone = false;
        if (!meta) {
            meta = [[NSMutableDictionary alloc] init];
        } else {
            //checkMeta
            isDone = [[meta objectForKey:kKeyDone] boolValue];
        }
        
        if (isDone) {
            url = [NSURL URLWithString:fullPath];
            fileSource = [[STKLocalFileDataSource alloc] initWithFilePath:url.path];
            fileSource.delegate = self;

            usingDataSource = fileSource;
        } else {
            httpSource = [[STKAutoRecoveringHTTPDataSource alloc] initWithHTTPDataSource:[[STKHTTPDataSource alloc] initWithURL:url]];
            httpSource.delegate = self;
#if BUFFER_SIZE
            buffer = (char*)malloc(BUFFER_SIZE);
#endif//BUFFER_SIZE
            usingDataSource = httpSource;
        }
    }
    return self;
}

-(void) dealloc {
    NSLog(@"Cached.dealloc");
#if BUFFER_SIZE
    if (buffer) {
        free(buffer);
        buffer = 0;
    }
#endif//BUFFER_SIZE
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
    NSLog(@"Cached.audioFileTypeHint");
    return audioFileTypeHint;
}

- (STKDataSource*)innerDataSource {
    NSLog(@"Cached.innerDataSource");
    return usingDataSource;
}

-(BOOL) registerForEvents:(NSRunLoop*)runLoop {
    NSLog(@"Cached.registerForEvents");
    return [super registerForEvents:runLoop];
}

-(void) unregisterForEvents {
    NSLog(@"Cached.unregisterForEvents");
    [super unregisterForEvents];
}

-(int) readIntoBuffer:(UInt8*)buffer withSize:(int)size {
    NSLog(@"Cached.readIntoBuffer");
    if (usingDataSource) {
        SInt64 offset = usingDataSource.position;
        int ret = [usingDataSource readIntoBuffer:buffer withSize:size];
        if (usingDataSource == httpSource && ret > 0) {
            // cache for http
            SInt64 len = usingDataSource.length;
            if (len > 0 && len < MAX_CACHE) {
                int oldLen = [[meta objectForKey:kKeyLength] intValue];
                if (oldLen == 0) {
                    oldLen = (int)len;
                    [meta setObject:[NSNumber numberWithInt:oldLen] forKey:kKeyLength];
                }
                if (oldLen == (int)len) {
                    if (writeBinary(fullPath.UTF8String, (uint32_t)offset, buffer, ret)) {
                        addChunk(meta, (uint32_t)offset, ret, oldLen);
                        [meta writeToFile:metaPath atomically:YES];
                    }
                }
            }
        }

        return ret;
    }
    return 0;
}

@end
