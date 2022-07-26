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

@interface STKCachedDataSource() {
    AudioFileTypeID audioFileTypeHint;
    STKLocalFileDataSource* fileSource;
    STKAutoRecoveringHTTPDataSource* httpSource;
    STKDataSource* usingDataSource;
}
@end

@implementation STKCachedDataSource

-(instancetype) initWithUrl:(NSURL*)url cachePath:(NSString*)path {
    if (self = [super init]) {
        NSString* md5 = [STKCachedDataSource Md5:[[url absoluteString] UTF8String]];
        NSString* extension = [[url path] pathExtension];
        audioFileTypeHint = [STKLocalFileDataSource audioFileTypeHintFromFileExtension:extension];
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

//@property (readonly) BOOL supportsSeek;
//@property (readonly) SInt64 position;
//@property (readonly) SInt64 length;
//@property (readonly) BOOL hasBytesAvailable;
//@property (nonatomic, readwrite, assign) double durationHint;
//@property (readwrite, unsafe_unretained, nullable) id<STKDataSourceDelegate> delegate;
//@property (nonatomic, strong, nullable) NSURL *recordToFileUrl;

-(AudioFileTypeID) audioFileTypeHint {
    return audioFileTypeHint;
}

-(void) dealloc {
    if (usingDataSource) {
        usingDataSource.delegate = nil;
    }
    fileSource = nil;
    usingDataSource = nil;
    httpSource = nil;
}

-(SInt64) length {
    return self.usingDataSource.length;
}

-(void) seekToOffset:(SInt64)offset {
    return [self.usingDataSource seekToOffset:offset];
}

-(int) readIntoBuffer:(UInt8*)buffer withSize:(int)size {
    return [self.usingDataSource readIntoBuffer:buffer withSize:size];
}

-(SInt64) position {
    return self.usingDataSource.position;
}

-(BOOL) registerForEvents:(NSRunLoop*)runLoop
{
    return [self.innerDataSource registerForEvents:runLoop];
}

-(void) unregisterForEvents {
    [self.innerDataSource unregisterForEvents];
}

-(void) close {
    [self.innerDataSource close];
}

-(BOOL) hasBytesAvailable {
    return self.innerDataSource.hasBytesAvailable;
}

-(void) dataSourceDataAvailable:(STKDataSource*)dataSource {
    [self.delegate dataSourceDataAvailable:self];
}

-(void) dataSourceErrorOccured:(STKDataSource*)dataSource {
    [self.delegate dataSourceErrorOccured:self];
}

-(void) dataSourceEof:(STKDataSource*)dataSource {
    [self.delegate dataSourceEof:self];
}

- (void)dataSource:(STKDataSource *)dataSource didReadStreamMetadata:(NSDictionary *)metadata
{
    [self.delegate dataSource:self didReadStreamMetadata:metadata];
}

-(BOOL) registerForEvents:(NSRunLoop*)runLoop {
    NSLog(@"registerForEvents");
    return NO;
}

-(void) unregisterForEvents {
    NSLog(@"unregisterForEvents");
}

-(void) close {
    NSLog(@"close");
    if (usingDataSource) {
        [usingDataSource close];
        fileSource = nil;
        usingDataSource = nil;
        httpSource = nil;
    }
}

-(void) seekToOffset:(SInt64)offset {
    NSLog(@"seekToOffset");
    if (usingDataSource) {
        [usingDataSource seekToOffset:offset];
    }
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
