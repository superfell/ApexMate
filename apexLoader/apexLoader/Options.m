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

#import "Options.h"


@implementation Options

- (BOOL)parseArguments:(NSArray *)args {
	BOOL expectFn = YES;
	if ([args count] == 1) {
		operation = opSetKeychain;
		return TRUE;
	}
	NSString *p = [args objectAtIndex:1];
	if ([p caseInsensitiveCompare:@"package"] == NSOrderedSame)  
		operation = opPackages;
	else if ([p caseInsensitiveCompare:@"trigger"] == NSOrderedSame) 
		operation = opTriggers;
	else if ([p caseInsensitiveCompare:@"apexpage"] == NSOrderedSame)
		operation = opApexPages;
	else if ([p caseInsensitiveCompare:@"runTests"] == NSOrderedSame) 
		operation = opRunTests;
	else if ([p caseInsensitiveCompare:@"execAnon"] == NSOrderedSame) 
		operation = opExecAnon;
	else if ([p caseInsensitiveCompare:@"setCredentials"] == NSOrderedSame) {
		operation = opSetKeychain;
		expectFn = NO;
	}
	if (expectFn) 
		filename = [[args objectAtIndex:2] retain];
	
	return TRUE;
}

- (void)dealloc {
	[filename release];
	[super dealloc];
}

- (NSString *)filename {
	return filename;
}

- (Operation)operation {
	return operation;
}

@end
