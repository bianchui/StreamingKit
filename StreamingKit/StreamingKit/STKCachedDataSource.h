//
//  STKCachedDataSource.h
//  StreamingKit
//
//  Created by bianchui on 2022/7/26.
//  Copyright © 2022 bianchui. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STKDataSourceWrapper.h"

@interface STKCachedDataSource : STKDataSourceWrapper

-(instancetype) initWithUrl:(NSURL*)url cachePath:(NSString*)cachePath;

@end
