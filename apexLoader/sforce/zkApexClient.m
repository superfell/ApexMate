// Copyright (c) 2006 Simon Fell
//
// Permission is hereby granted, free of charge, to any person obtaining a 
// copy of this software and associated documentation files (the "Software"), 
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, 
// and/or sell copies of the Software, and to permit persons to whom the 
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included 
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS 
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
// THE SOFTWARE.
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
	endpointUrl = [[NSString stringWithFormat:@"%@://%@/services/Soap/s/22.0", [su scheme], [su host]] copy];
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
