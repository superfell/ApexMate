//
//  zkApexClient.m
//  apexCoder
//
//  Created by Simon Fell on 5/29/07.
//  Copyright 2007 Simon Fell. All rights reserved.
//

#import "zkApexClient.h"
#import "ZKEnvelope.h"
#import "zkCompileResult.h"
#import "zkExecuteAnonResult.h"
#import "zkRunTestResult.h"

@implementation ZKApexClient

+ (id) fromClient:(ZKSforceClient *)sf {
	return [[[ZKApexClient alloc] initFromClient:sf] autorelease];
}

- (id) initFromClient:(ZKSforceClient *)sf {
	self = [super init];
	sforce = [sf retain];
	return self;
}

- (void)dealloc {
	[sforce release];
	[super dealloc];
}

- (void)setEndpointUrl {
	[endpointUrl release];
	NSURL *su = [NSURL URLWithString:[sforce serverUrl]];
	endpointUrl = [[NSString stringWithFormat:@"%@://%@/services/Soap/s/9.0", [su scheme], [su host]] copy];
}

- (ZKEnvelope *)startEnvelope {
	ZKEnvelope *e = [[[ZKEnvelope alloc] init] autorelease];
	[e start:@"http://soap.sforce.com/2006/08/apex"];
	[e writeSessionHeader:[sforce sessionId]];
	[e writeCallOptionsHeader:[sforce clientId]];
	[e moveToBody];
	[self setEndpointUrl];
	return e;
}

- (NSArray *)sendAndParseResults:(ZKEnvelope *)requestEnv resultType:(Class)resultClass {
	NSError * err = NULL;
	NSXMLNode * resRoot = [self sendRequest:[requestEnv end]];
	NSArray * results = [resRoot nodesForXPath:@"result" error:&err];
	NSMutableArray *resArr = [NSMutableArray array];
	NSEnumerator * e = [results objectEnumerator];
	NSXMLElement *xmle;
	while (xmle = [e nextObject]) {
		NSObject *o = [[resultClass alloc] initWithXmlElement:xmle];
		[resArr addObject:o];
		[o release];
	}
	return resArr;
}

- (NSArray *)compile:(NSString *)elemName src:(NSArray *)src {
	ZKEnvelope * env = [self startEnvelope];
	[env startElement:elemName];
	[env addElementArray:@"scripts" elemValue:src];
	[env endElement:elemName];
	[env endElement:@"s:Body"];
	return [self sendAndParseResults:env resultType:[ZKCompileResult class]];
}

- (NSArray *)compilePackages:(NSArray *)src {
	return [self compile:@"compilePackages" src:src];
}

- (NSArray *)compileTriggers:(NSArray *)src {
	return [self compile:@"compileTriggers" src:src];
}

- (ZKExecuteAnonymousResult *)executeAnonymous:(NSString *)src {
	ZKEnvelope * env = [self startEnvelope];
	[env startElement:@"executeAnonymous"];
	[env addElement:@"String" elemValue:src];
	[env endElement:@"executeAnonymous"];
	[env endElement:@"s:Body"];
	return [[self sendAndParseResults:env resultType:[ZKExecuteAnonymousResult class]] objectAtIndex:0];
}

- (ZKRunTestResult *)runTests:(BOOL)allTests namespace:(NSString *)ns packages:(NSArray *)pkgs {
	ZKEnvelope *env = [self startEnvelope];
	[env startElement:@"runTests"];
	[env startElement:@"RunTestsRequest"];
	[env addElement:@"allTests" elemValue:allTests ? @"true" : @"false"];
	[env addElement:@"namespace" elemValue:ns];
	[env addElement:@"packages" elemValue:pkgs];
	[env endElement:@"RunTestsRequest"];
	[env endElement:@"runTests"];
	[env endElement:@"s:Body"];
	return [[self sendAndParseResults:env resultType:[ZKRunTestResult class]] objectAtIndex:0];
}

@end
