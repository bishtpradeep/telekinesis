//
//  TKController.m
//  Telekinesis
//
//  Created by Nicholas Jitkoff on 6/14/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "TKController.h"
#import "SimpleHTTPConnection.h"
#import "SimpleHTTPServer.h"
#import <stdio.h>
#import <string.h>
#import <sys/socket.h>
#include <arpa/inet.h>
#import "NSURL+Parameters.h"
#import "glgrab.h"

#import "QSKeyCodeTranslator.h"

@interface TKController (PrivateMethods)
- (NSString *)applicationSupportFolder;
  //- (NSURL *)currentURL;
@end


void CatchInterrupt (int signum) {
  pid_t my_pid;
  
  printf("\nReceived an interrupt! About to exit ..\n");
  
  fflush(stdout);
  
  [[NSApp delegate] stopApache];
  my_pid = getpid();
  kill(my_pid, SIGKILL);
}


@implementation TKController
+ (void) initialize {
  signal(SIGTERM, CatchInterrupt);  
}

- (id) init {
  self = [super init];
  if (self != nil) {
    [self setServer:[[[SimpleHTTPServer alloc] initWithTCPPort:5011
                                                      delegate:self] autorelease]];
    
    [self applicationSupportFolder];
    NSFileManager *fm = [NSFileManager defaultManager];
      
    [fm createDirectoryAtPath:[self applicationSupportFolder] attributes:nil];
    [fm createDirectoryAtPath:[[self applicationSupportFolder] stringByAppendingPathComponent:@"apps"] attributes:nil];
    
    [self startApache];
  }
  return self;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
  [self goHome:nil];
  return NO; 
}

- (void) goHome:(id)sender {
  NSString *urlString = [NSString stringWithFormat:@"https://%@:%d", @"localhost", 5010];
  [[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:[NSURL URLWithString:urlString]]
                  withAppBundleIdentifier:@"com.apple.Safari"
                                  options:nil additionalEventParamDescriptor:nil launchIdentifiers:nil];
//
//NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
//NSLog(@"request %@", urlString);
//[[webView mainFrame] loadRequest:request];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
  [self performSelector:@selector(goHome:) withObject:nil afterDelay:1.0];
}
- (void)dealloc
{
  [apacheTask terminate];
  [apacheTask release];
  apacheTask = nil;
  
  [server release];
  [super dealloc];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
  [self stopApache]; 
}

- (void) startApache {
  NSString *root = [[NSBundle mainBundle] resourcePath];
  
  NSString *documentRoot = root;
  
  if ([[NSUserDefaults standardUserDefaults] boolForKey:@"useSourceWebDirectory"]) {
   documentRoot =  @"/Volumes/Lux/telekinesis/trunk/";
    NSLog(@"using lux root");
  }
    
  NSString *document = [[NSBundle mainBundle] pathForResource:@"www" ofType:nil];
  
  
  BOOL apache2= [[NSFileManager defaultManager] fileExistsAtPath:@"/etc/apache2/"];
  NSString *config = [[NSBundle mainBundle] pathForResource:(apache2 ? @"httpd.2.0" : @"httpd.1.3.33") ofType:@"conf"];
  
  
  NSMutableArray *arguments = [NSMutableArray arrayWithObjects:
      @"-d", root,
      @"-f", config,
    nil];
  
  
  NSMutableArray *directives = [NSMutableArray arrayWithObjects:
    [NSString stringWithFormat:@"Alias /resources/ \"%@\"", root],
    [NSString stringWithFormat:@"ErrorLog \"%@/Library/Logs/Telekinesis_error.log\"", NSHomeDirectory()],
    [NSString stringWithFormat:@"CustomLog \"%@/Library/Logs/Telekinesis_access.log\" common", NSHomeDirectory()],
    [NSString stringWithFormat:@"DocumentRoot \"%@/www/\"", documentRoot],
    [NSString stringWithFormat:@"Alias /apps/ \"%@/Library/Application Support/Telekinesis/Apps/\"",  NSHomeDirectory()],
    [NSString stringWithFormat:@"Alias /home/ \"%@/\"",  NSHomeDirectory()],
    [NSString stringWithFormat:@"ScriptAlias /cgi/ \"%@/cgi-bin/\"",  documentRoot],
    nil];
      
  NSEnumerator *e = [directives objectEnumerator];
  id item;
  while (item = [e nextObject]) {
    [arguments addObject:@"-c"];
    [arguments addObject:item];
  }
  
  apacheTask = [[NSTask launchedTaskWithLaunchPath:@"/usr/sbin/httpd"
                                         arguments:arguments] retain];
}

- (void) stopApache {
  NSLog(@"stop %@", apacheTask);
  
  [apacheTask terminate];
  [apacheTask waitUntilExit];
  
  // This isn't working... killall for now
  system("killall httpd");
  NSLog(@"stop %@", apacheTask);
  [apacheTask release];
  apacheTask = nil;
}



- (void) generateCertificate {
  
  
  NSString *certgen = [[NSBundle mainBundle] pathForResource:@"gencert" ofType:@"sh"];
  NSString *certconfig = [[NSBundle mainBundle] pathForResource:@"gencert" ofType:@"sh"];
  NSString *appsupport = [self applicationSupportFolder];
  NSString *outfile = [appsupport stringByAppendingPathComponent:@"out.pem"];
  NSString *outkeyfile = [appsupport stringByAppendingPathComponent:@"out.keyfile.pem"];
  NSTask *task = [NSTask launchedTaskWithLaunchPath:certgen
                                          arguments:[NSArray arrayWithObjects:
                                            certconfig,
                                            outfile,
                                            outkeyfile,
                            // openssl req  -config $1 -keyout $2 -newkey rsa:1024 -nodes -x509 -days 365 -out $3
                                            
                                            nil]];
  [task waitUntilExit];
}













- (void)setServer:(SimpleHTTPServer *)sv
{
  [server autorelease];
  server = [sv retain];
}

- (SimpleHTTPServer *)server { return server; }


- (void)processTelekinesis:(NSDictionary *)params connection:(SimpleHTTPConnection *)connection {
  
  
}


- (NSString *)applicationSupportFolder
{
  
	NSString *appSupportFolder = [@"~/Library/Application Support/Telekinesis/" stringByStandardizingPath];
  NSFileManager *manager = [NSFileManager defaultManager];
  
  if( ![manager fileExistsAtPath:appSupportFolder] )
		[manager createDirectoryAtPath:appSupportFolder attributes:nil];	
	
  return appSupportFolder;
  
  
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
  
  NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
  
  
	basePath = [basePath stringByAppendingPathComponent:@"Cultured Code"];
	if( ![manager fileExistsAtPath:basePath] ) {
		[manager createDirectoryAtPath:basePath attributes:nil];
  }
  
}





// Nasty function that handles most of the advanced functionality

- (void)processURL:(NSURL *)url connection:(SimpleHTTPConnection *)connection {
  NSLog(@"URL %@", url);
  
  NSData *data = nil;
  NSString *mime = nil;
  NSString *path = [url path];
  
  if ([path isEqualToString:@"/"]) path = @"/index.html";
#pragma mark Get the screen
  if ([[url path] isEqualToString:@"/screen.png"] || [[url path] hasPrefix: @"/grabscreen"]) {
    NSString *mode = [[url parameterDictionary] objectForKey:@"mode"];
    CGRect rect;
    
    CGDirectDisplayID displayID = CGMainDisplayID();
    if (!mode) {
      
      rect = CGDisplayBounds(displayID);
    } else if ([mode isEqualToString:@"update"]) {
      rect = CGRectMake(100*region,0,100,100);
      
      region = (region + 1) % 4;
    } else if ([mode isEqualToString:@"region"]) {
      rect = CGRectMake(100*region,0,100,100);
    }
    
    NSRect screenFrame = [[NSScreen mainScreen] frame];
    
    CGImageRef theCGImage = grabViaOpenGL(displayID, rect);
    
    NSMutableData* imageData = [NSMutableData data];
    CGImageDestinationRef destCG = CGImageDestinationCreateWithData((CFMutableDataRef)imageData,  kUTTypePNG,1,NULL);
    CGImageDestinationAddImage(destCG, theCGImage, NULL);
    CGImageDestinationFinalize(destCG);
    data = imageData;
    mime = @"image/png";
    
    NSDictionary *headers = [NSDictionary dictionaryWithObjectsAndKeys:
      mime, @"Content-Type",
      [NSString stringWithFormat:@"name=%d+%d", (int)rect.origin.x, (int)rect.origin.y], @"Set-Cookie",
      nil];
    
    [server replyWithStatusCode:200 headers:headers body:data];  // 200 = 'OK'
    usleep(100000);
    return;
    
    
#pragma mark Run a script
  } else if ([[url path] hasPrefix:@"/runscript"]) {
    NSDictionary *params =  [url parameterDictionary];
    
    NSString *path = [[params objectForKey:@"path"] stringByStandardizingPath];
    NSAppleScript *script = nil;
    if (path) {
      path = [path stringByStandardizingPath];
      if (![path hasPrefix:@"/"]) path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:path];
      NSLog(@"path %@", path);
      
      script = [[[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]
                                                       error:nil] autorelease];
      
    } else {
      NSString *source = [params objectForKey:@"source"];
      
      if (source) {
        script = [[[NSAppleScript alloc] initWithSource:source] autorelease];
      }
      
    }
    
    NSAppleEventDescriptor *descriptor = [script executeAndReturnError:nil];
    data = [[descriptor stringValue] dataUsingEncoding:NSUTF8StringEncoding];
    mime = @"text/plain";
    
    [server replyWithStatusCode:200 message:@""];
    return;
    
#pragma mark Get an icon
  } else if ([[url path] hasPrefix:@"/icon"]) {
    NSDictionary *params =  [url parameterDictionary];
    
    NSString *path = [[params objectForKey:@"path"] stringByStandardizingPath];
    NSSize size = NSSizeFromString([params objectForKey:@"size"]);
    
    NSImage *image = [[NSWorkspace sharedWorkspace] iconForFile:path];
    
    if (!NSEqualSizes(size,NSZeroSize)) [image setSize:size];
        
        data = [[image bestRepresentationForDevice:nil] representationUsingType:NSPNGFileType properties:nil];
   mime = @"image/png";    
        
#pragma mark click
  } else if ([[url path] hasPrefix: @"/click"]) {
    
    NSDictionary *params =  [url parameterDictionary];
    //;hi?31,191
    NSArray *points = [[url query] componentsSeparatedByString:@","];
    CGPoint p;
    p.x = [[params objectForKey:@"x"] intValue];
    p.y = [[params objectForKey:@"y"] intValue];
    CGWarpMouseCursorPosition(p);
    
    CGPostMouseEvent(p, 0, 1, 1);
    CGPostMouseEvent(p, 0, 1, 0);    
    [server replyWithStatusCode:200 message:@""];
    
    return;
#pragma mark move
  } else if ([[url path] hasPrefix: @"/mousemove"]) {
    
    NSDictionary *params =  [url parameterDictionary];
    //;hi?31,191
    NSArray *points = [[url query] componentsSeparatedByString:@","];
    CGPoint p;
    p.x = [[params objectForKey:@"x"] intValue];
    p.y = [[params objectForKey:@"y"] intValue];
    CGWarpMouseCursorPosition(p);
    
    [server replyWithStatusCode:200 message:@""];
    
    return;
    
#pragma mark keypress
  } else if ([[url path] hasPrefix: @"/telekinesis"]) {
    NSDictionary *params =  [url parameterDictionary];
    if (1 || [[params objectForKey:@"t"] isEqualToString:@"keyup"]) {
      
      NSString *string = [params objectForKey:@"string"];
      NSString *character = [params objectForKey:@"c"];
      
      
      int i;
      for (i = 0; i < [string length]; i++) {
        unichar c = [string characterAtIndex:i];
        
        BOOL shift = isupper(c);//[[params objectForKey:@"s"] isEqualToString:@"true"];
          
          short code = [QSKeyCodeTranslator AsciiToKeyCode:c];
          NSLog(@"char '%c' %d", c, shift);
          if (shift) CGPostKeyboardEvent( (CGCharCode)0, (CGKeyCode)56, true ); // shift down
          CGPostKeyboardEvent(0, code, YES);
          CGPostKeyboardEvent(0, code, NO);
          if (shift) CGPostKeyboardEvent( (CGCharCode)0, (CGKeyCode)56, false ); // 'shift up
      }
    }
    [server replyWithStatusCode:200 message:@""];
    
    return;
    
    
    
    
#pragma mark return path
  } else {
    NSArray *components = [path pathComponents];
    //components = [components subarrayWithRange:NSMakeRange(2,[components count]-2)];
    //path = [NSString pathWithComponents:components];
    path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:path];
    NSLog(@"path %@", path);
    data = [NSData dataWithContentsOfMappedFile:path];
    mime = @"";
  } 
  
  if(data && mime) {
    [server replyWithData: data
                 MIMEType: mime];
  } else {
    NSString *errorMsg = [NSString stringWithFormat:@"Error in URL: %@", url];
    NSLog(@"%@", errorMsg);
    [server replyWithStatusCode:400 // Bad Request
                        message:errorMsg];
  }
}

- (void)stopProcessing {
  
}

@end

