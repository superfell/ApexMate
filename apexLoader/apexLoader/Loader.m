// Copyright (c) 2007-2008,2011 Simon Fell
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

#import "Loader.h"
#import "Options.h"
#import "zkSforceClient.h"
#import	"ZKCompileResult.h"
#import "zkApexClient.h"
#import "zkExecuteAnonResult.h"
#import "zkRunTestResult.h"
#import "zkRunTestFailure.h"
#import "zkSObject.h"
#import "zkSaveResult.h"

@implementation Loader

- (id)initWithSforce:(ZKSforceClient *)sf {
	self = [super init];
	sforce = [sf retain];
	apex = [[ZKApexClient fromClient:sf] retain];
	return self;
}

- (void)dealloc {
	[sforce release];
	[apex release];
	[super dealloc];
}

- (void)logHtml:(NSString *)fmt withLevel:(LogLevel)lvl {
	NSString *div = lvl == logError ? @" class='err'" : @"";
	printf("<div%s>%s</div>\n", [div UTF8String], [fmt UTF8String]);
}

- (NSString *)operationDescription {
	switch (operation) {
		case opPackages: return @"Compiling Apex Class";
		case opTriggers: return @"Compiling Apex Trigger";
		case opApexPages: return @"Deploying Apex Page";
		case opExecAnon: return @"Execute Anonymous";
		case opRunTests: return @"Running Apex Unit Tests";
		case opSetKeychain: return @"Saving Credentials";
	}
	return @"";
}


- (void)initOutput {
	printf("<html><head><style type='text/css'>BODY { background-color:navy; color:white; margin:6pt; }");
	printf(".err { color:red; background-color:blue; }\r\n");
	printf("A { color:red }\r\n");
	printf(".ct { margin-left:6pt; }\r\n");
	printf("H1 { margin:3pt; font-size:1.2em; background-color:black; color:white; padding:3pt; border:thin dotted white; }</style></head><body>");
	printf("<h1>%s</h1><div class='ct'>", [[self operationDescription] UTF8String]);
}

- (void)finalizeOutput {
	printf("</div></body></html>");
}

- (void)log:(LogLevel)level msg:(NSString *)fmt {
	[self logHtml:fmt withLevel:level];
}

- (NSString *)textMateUrlforLine:(int)ln column:(int)col {
	return [NSString stringWithFormat:@"txmt://open?line=%d&column=%d", ln, col];
}

- (void)logCompileError:(NSString *)problem line:(int)ln column:(int)col {
	NSString *txtMateUrl = [self textMateUrlforLine:ln column:col];
	[self log:logError msg:[NSString stringWithFormat:@"Compile Error: <a href='%@'>%@ at line %d col %d</a>", txtMateUrl, problem, ln, col]];
}

- (void)logCompileError:(ZKCompileResult *)r {
	[self logCompileError:[r problem] line:[r line] column:[r column]];
}

- (NSArray *)loadFile:(NSString *)file {
	NSMutableArray *res = [NSMutableArray array];
	NSError *err = nil;
	NSString *c = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:&err];
	if (err != nil) 
		[self log:logError msg:[NSString stringWithFormat:@"%@ : %@", file, [err localizedDescription]]];
	if (c != nil)
		[res addObject:c];
	return res;
}

- (int)load:(NSString *)file isTrigger:(BOOL)isTrigger {
	[self log:logVerbose msg:[NSString stringWithFormat:@"About to load %@ %@", isTrigger ? @"Trigger" : @"Class", file]];

	NSArray *src = [self loadFile:file];	
	NSArray *results = isTrigger ? [apex compileTriggers:src] : [apex compilePackages:src];

	ZKCompileResult *r;
	NSEnumerator *e = [results objectEnumerator];
	int errCount = 0;
	while (r = [e nextObject]) {
		if ([r success]) 
			[self log:logVerbose msg:[NSString stringWithFormat:@"Success! (Id is %@  CRC is %x)", [r id], [r bodyCrc]]];
		else {
			[self logCompileError:r];
			++errCount;
		}
	}
	return -errCount;
}

- (int)runTests:(NSString *)filename {
	[self log:logVerbose msg:[NSString stringWithFormat:@"About to run tests from %@", filename]];
	ZKRunTestResult *res = [apex runTests:NO namespace:@"" packages:[NSArray arrayWithObject:filename]];
	if ([res numFailures] > 0) {
		[self log:logError msg:[NSString stringWithFormat:@"Failed: %d of %d tests failed", [res numFailures], [res numTestsRun]]];
		int c = 1;
		NSEnumerator *e = [[res failures] objectEnumerator];
		ZKRunTestFailure *f;
		while ( f = [e nextObject]) {
			[self log:logError msg:[NSString stringWithFormat:@"%d. %@.%@ - %@", c++, [f packageName], [f methodName], [f message]]];
		}
	} else {
		[self log:logVerbose msg:[NSString stringWithFormat:@"Success: %d of %d tests failed", [res numFailures], [res numTestsRun]]];
	}
	return -[res numFailures];
}

- (int)execAnon:(NSString *)filename {
	[self log:logVerbose msg:[NSString stringWithFormat:@"About to execute script %@", filename]];
	NSArray *src = [self loadFile:filename];	
	NSString *apexSrc;
	NSEnumerator *e = [src objectEnumerator];
	int errCount = 0;
	while (apexSrc = [e nextObject]) {
		ZKExecuteAnonymousResult *r = [apex executeAnonymous:apexSrc];
		++errCount;
		if (![r compiled]) 
			[self logCompileError:[r compileProblem] line:[r line] column:[r column]];
		else if (![r success]) {
			[self log:logError msg:[NSString stringWithFormat:@"Exception %@\n%@", [r exceptionMessage], [r exceptionStackTrace]]];
		} else {
			--errCount;
		}
	}
	return -errCount;
}

-(int)loadPage:(NSString *)filename {
	[self log:logVerbose msg:[NSString stringWithFormat:@"About to deploy apex page: %@", filename]];
	NSArray *src = [self loadFile:filename];
	int errCount = 0;
	for (NSString *psrc in src) {
		ZKSObject *page = [[[ZKSObject alloc] initWithType:@"ApexPage"] autorelease];
		[page setFieldValue:psrc field:@"Markup"];
		NSString *name = [[filename lastPathComponent] stringByDeletingPathExtension];
		[page setFieldValue:name field:@"Name"];
		[page setFieldValue:name field:@"MasterLabel"];
		ZKSaveResult *sr = [[sforce upsert:@"Name" objects:[NSArray arrayWithObject:page]] objectAtIndex:0];
		if (![sr success]) {
			[self log:logError msg:[NSString stringWithFormat:@"%@ : %@", [sr statusCode], [sr message]]];
			errCount++;
		} else {
			[self log:logVerbose msg:[NSString stringWithFormat:@"Success! ApexPage upserted with Id %@", [sr id]]];
		}
	}
	return -errCount;
}

- (int) performOperation:(Options *)op {
	operation = [op operation];
	[self initOutput];
	@try {
		switch ([op operation]) {
			case opPackages:
				return [self load:[op filename] isTrigger:NO];
			case opTriggers:
				return [self load:[op filename] isTrigger:YES];
			case opApexPages:
				return [self loadPage:[op filename]];
			case opExecAnon:
				return [self execAnon:[op filename]];
			case opRunTests:
				return [self runTests:[op filename]];
		}
	}
	@finally {
		[self finalizeOutput];
	}
	return -42;
}

@end
