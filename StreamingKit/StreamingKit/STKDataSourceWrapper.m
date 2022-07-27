/**********************************************************************************
 AudioPlayer.m

 Created by Thong Nguyen on 16/10/2012.
 https://github.com/tumtumtum/audjustable

 Copyright (c) 2012 Thong Nguyen (tumtumtum@gmail.com). All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 3. All advertising materials mentioning features or use of this software
 must display the following acknowledgement:
 This product includes software developed by Thong Nguyen (tumtumtum@gmail.com)
 4. Neither the name of Thong Nguyen nor the
 names of its contributors may be used to endorse or promote products
 derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY Thong Nguyen''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 **********************************************************************************/

#import "STKDataSourceWrapper.h"

@interface STKDataSourceWrapper()
@property (readwrite) STKDataSource* innerDataSource;
@end

@implementation STKDataSourceWrapper

-(instancetype) initWithDataSource:(STKDataSource*)innerDataSourceIn
{
    if (self = [super init])
    {
        self.innerDataSource = innerDataSourceIn;
        
        self.innerDataSource.delegate = self;
    }
    
    return self;
}

-(AudioFileTypeID) audioFileTypeHint
{
    NSLog(@"Wrapper.audioFileTypeHint");
    return self.innerDataSource.audioFileTypeHint;
}

-(void) dealloc
{
    NSLog(@"Wrapper.dealloc");
    self.innerDataSource.delegate = nil;
}

-(SInt64) length
{
    NSLog(@"Wrapper.length");
    return self.innerDataSource.length;
}

-(void) seekToOffset:(SInt64)offset
{
    NSLog(@"Wrapper.seekToOffset");
    return [self.innerDataSource seekToOffset:offset];
}

-(int) readIntoBuffer:(UInt8*)buffer withSize:(int)size
{
    NSLog(@"Wrapper.readIntoBuffer");
    return [self.innerDataSource readIntoBuffer:buffer withSize:size];
}

-(SInt64) position
{
    NSLog(@"Wrapper.position");
    return self.innerDataSource.position;
}

-(BOOL) registerForEvents:(NSRunLoop*)runLoop
{
    NSLog(@"Wrapper.registerForEvents");
    return [self.innerDataSource registerForEvents:runLoop];
}

-(void) unregisterForEvents
{
    NSLog(@"Wrapper.unregisterForEvents");
    [self.innerDataSource unregisterForEvents];
}

-(void) close
{
    NSLog(@"Wrapper.close");
    [self.innerDataSource close];
}

-(BOOL) hasBytesAvailable
{
    NSLog(@"Wrapper.hasBytesAvailable");
    return self.innerDataSource.hasBytesAvailable;
}

-(void) dataSourceDataAvailable:(STKDataSource*)dataSource
{
    NSLog(@"Wrapper.dataSourceDataAvailable");
    [self.delegate dataSourceDataAvailable:self];
}

-(void) dataSourceErrorOccured:(STKDataSource*)dataSource
{
    NSLog(@"Wrapper.dataSourceErrorOccured");
    [self.delegate dataSourceErrorOccured:self];
}

-(void) dataSourceEof:(STKDataSource*)dataSource
{
    NSLog(@"Wrapper.dataSourceEof");
    [self.delegate dataSourceEof:self];
}

- (void)dataSource:(STKDataSource *)dataSource didReadStreamMetadata:(NSDictionary *)metadata
{
    NSLog(@"Wrapper.dataSource didReadStreamMetadata: %@", metadata);
    [self.delegate dataSource:self didReadStreamMetadata:metadata];
}

@end
