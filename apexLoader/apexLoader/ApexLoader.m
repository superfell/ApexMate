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

#import "ApexLoader.h"
#import "Options.h"
#import "ZKLoginController.h"
#import "Loader.h"

@interface ApexLoader (Private)
- (void)showLogin:(id)sender;
- (void)doAuthenticatedOperation:(id)sender;
@end 

@implementation ApexLoader

+ (void)initialize {
	NSMutableDictionary * defaults = [NSMutableDictionary dictionary];
	NSString *prod = [NSString stringWithString:@"https://www.salesforce.com"];
	NSString *test = [NSString stringWithString:@"https://test.salesforce.com"];
	NSMutableArray * defaultServers = [NSMutableArray arrayWithObjects:prod, test, nil];
	[defaults setObject:defaultServers forKey:@"servers"];
	[defaults setObject:prod forKey:@"server"];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void)dealloc {
	[login release];
	[options release];
	[super dealloc];
}

- (void)finishedLaunching:(id)sender {
	options = [[Options alloc] init];
	if (![options parseArguments:[[NSProcessInfo processInfo] arguments]]) {
		// show error
		return;
	}
	switch ([options operation]) {
		case opPackages:
		case opTriggers:
		case opApexPages:
		case opRunTests:
		case opExecAnon:
			[self performSelectorOnMainThread:@selector(doAuthenticatedOperation:) withObject:nil waitUntilDone:NO];
			break;
		case opSetKeychain:
			[self performSelectorOnMainThread:@selector(showLogin:) withObject:nil waitUntilDone:NO];
	}
}

- (void)awakeFromNib {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finishedLaunching:) name:NSApplicationDidFinishLaunchingNotification object:nil];
}

- (void)loginComplete:(id)sender {
	[NSApp terminate:self];
}

- (void)initLoginController {
	[login release];
	login = [[ZKLoginController alloc] init];
	[login setClientIdFromInfoPlist];
}

- (void)showLogin:(id)sender {
	[self initLoginController];
	[login showLoginWindow:self target:self selector:@selector(loginComplete:)];
}

- (void)performAuthenticatedOperation:(id)sforce {
	Loader * loader = [[[Loader alloc] initWithSforce:sforce] autorelease];
	[loader performOperation:options];
	[NSApp terminate:self];
}

- (void)doAuthenticatedOperation:(id)sender {
	[self initLoginController];
	ZKSoapException *ex = nil;
	ZKSforceClient *sforce = [login performLogin:&ex];
	if (ex == nil) {
		[self performAuthenticatedOperation:sforce];
	} else {
		[login setStatusText:[ex reason]];
		[login showLoginWindow:self target:self selector:@selector(performAuthenticatedOperation:)];
	} 
}

@end
