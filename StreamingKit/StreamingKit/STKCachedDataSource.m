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
    if ([[meta objectForKey:kKeyDone] boolValue]) {
        return true;
    }
    id chunks = [meta objectForKey:kKeyChunks];
    if (chunks && ![chunks isKindOfClass:[NSMutableArray class]]) {
        if ([chunks isKindOfClass:[NSArray class]]) {
            chunks = [chunks mutableCopy];
        } else {
            chunks = nil;
        }
    }
    if (!chunks) {
        chunks = [NSMutableArray arrayWithCapacity:10];
    }
    uint32_t startChunk = off;
    uint32_t endChunk = off + size;
    NSUInteger count = [chunks count];
    bool find = false;
    // (start, end), (start, end)
    for (NSUInteger i = 0; i < count; i += 2) {
        uint32_t end = [[chunks objectAtIndex:i + 1] intValue];
        if (end < startChunk) {
            // end, GAP, startChunk
            continue;
        }
        find = true;
        uint32_t start = [[chunks objectAtIndex:i] intValue];
        if (endChunk < start) {
            // endChunk, GAP, start: insert at i
            [chunks insertObject:[NSNumber numberWithInt:startChunk] atIndex:i];
            [chunks insertObject:[NSNumber numberWithInt:endChunk] atIndex:i + 1];
            break;
        }

        // merge with current chunk
        if (start <= startChunk) {
            // start, startChunk => start
            startChunk = start;
        } else {
            // startChunk, start => startChunk
            [chunks setObject:[NSNumber numberWithInt:startChunk] atIndex:i];
        }
        if (endChunk <= end) {
            // endChunk, end => end
            endChunk = end;
        } else {
            // end, endChunk => endChunk
            // extends end of current chunk, try merge follow chunks
            NSUInteger j = i + 2;
            while (j < count) {
                start = [[chunks objectAtIndex:j] intValue];
                if (endChunk < start) {
                    // endChunk, GAP, start
                    break;
                }
                end = [[chunks objectAtIndex:j + 1] intValue];
                // erase anyway
                [chunks removeObjectAtIndex:j];
                [chunks removeObjectAtIndex:j];
                if (endChunk <= end) {
                    // endChunk, end => end
                    endChunk = end;
                    break;
                }
                // end, endChunk => endChunk
                count -= 2;
            }
            [chunks setObject:[NSNumber numberWithInt:endChunk] atIndex:i + 1];
        }
        break;
    }
    
    const bool done = startChunk == 0 && endChunk == total;
    
    if (!find) {
        [chunks addObject:[NSNumber numberWithInt:startChunk]];
        [chunks addObject:[NSNumber numberWithInt:endChunk]];
    }
    
    if (done) {
        [meta setObject:[NSNumber numberWithBool:true] forKey:kKeyDone];
    }
    
    [meta setObject:chunks forKey:kKeyChunks];
    return true;
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
    NSLog(@"audioFileTypeHint");
    return audioFileTypeHint;
}

- (STKDataSource*)innerDataSource {
    //NSLog(@"innerDataSource");
    return usingDataSource;
}

-(BOOL) registerForEvents:(NSRunLoop*)runLoop {
    //NSLog(@"registerForEvents");
    return [super registerForEvents:runLoop];
}

-(void) unregisterForEvents {
    //NSLog(@"unregisterForEvents");
    [super unregisterForEvents];
}

-(int) readIntoBuffer:(UInt8*)buffer withSize:(int)size {
    //NSLog(@"readIntoBuffer");
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
