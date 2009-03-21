//
//  zkApexClient.h
//  apexCoder
//
//  Created by Simon Fell on 5/29/07.
//  Copyright 2007 Simon Fell. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "zkSforceClient.h"

@class ZKExecuteAnonymousResult;
@class ZKRunTestResult;

@interface ZKApexClient : ZKBaseClient {
	ZKSforceClient	*sforce;
}

+ (id) fromClient:(ZKSforceClient *)sf;
- (id) initFromClient:(ZKSforceClient *)sf;

- (NSArray *)compilePackages:(NSArray *)src;
- (NSArray *)compileTriggers:(NSArray *)src;
- (ZKExecuteAnonymousResult *)executeAnonymous:(NSString *)src;
- (ZKRunTestResult *)runTests:(BOOL)allTests namespace:(NSString *)ns packages:(NSArray *)pkgs;
@end
