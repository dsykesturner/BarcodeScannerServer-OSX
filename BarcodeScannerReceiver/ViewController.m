//
//  ViewController.m
//  BarcodeScannerReceiver
//
//  Created by Daniel Sykes-Turner on 13/3/17.
//  Copyright © 2017 Universe Apps. All rights reserved.
//

#import "ViewController.h"
#import "ServerConnection.h"
#import "AppConfig.h"

#import <IOKit/IOKitLib.h>
#include <CoreGraphics/CoreGraphics.h>
#include <Carbon/Carbon.h> /* For kVK_ constants, and TIS functions. */


@interface ViewController () <ServerConnectionDelegate>
@property (nonatomic, weak) IBOutlet NSTextField *lblConnectedStatus;
@property (nonatomic, weak) IBOutlet NSTextField *txtLaptopName;
@property (nonatomic, strong) ServerConnection* connection;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    self.lblConnectedStatus.stringValue = @"Disconnected";
    
    // Set device name
    NSString *uniqueIdentifier = [self serialNumber];
    [AppConfig getInstance].name = uniqueIdentifier;
    self.txtLaptopName.stringValue = uniqueIdentifier;
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    [self createServerConnection];
    [self.txtLaptopName becomeFirstResponder];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (void)createServerConnection {
    
    // Stop a previous connection if it exists
    if (self.connection)
        [self.connection stop];
    
    // Create a server connection and start it
    self.connection = [[ServerConnection alloc] init];
    self.connection.delegate = self;
    if (![self.connection start]) {
        NSLog(@"FAILED to stat server connection broadcase");
    } else {
        self.lblConnectedStatus.stringValue = @"Broadcasting";
    }
}

- (void)writeTextToWindow:(NSString *)text {
    
    NSArray *runningApplications = [[NSWorkspace sharedWorkspace] runningApplications]; // depreciated but I couldn't find a modern way to get the Carbon PSN
    NSLog(@"apps: %@", runningApplications);
    NSRunningApplication *app;
    for (NSRunningApplication *a in runningApplications) {
        if (a.isActive) {
            app = a;
            break;
        }
    }
    
    int len = (int)text.length;
    char buffer[len];
    strncpy(buffer, text.UTF8String, len);
//    [text getCharacters:buffer range:NSMakeRange(0, len)];
    for (int i = 0; i < len; i++) {
        char c = buffer[i];
        
        CGEventRef keyDown = CGEventCreateKeyboardEvent(NULL, [self keyCodeForChar:c], true);
        CGEventRef keyUp = CGEventCreateKeyboardEvent(NULL, [self keyCodeForChar:c], false);
        
        CGEventPostToPid(app.processIdentifier, keyDown);
        CGEventPostToPid(app.processIdentifier, keyUp);
    }
    
    // Add a new line (CGKeyCode = 36)
    CGEventRef keyDown = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)36, true);
    CGEventRef keyUp = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)36, false);
    
    CGEventPostToPid(app.processIdentifier, keyDown);
    CGEventPostToPid(app.processIdentifier, keyUp);
}

- (CGKeyCode)keyCodeForChar:(const char)c {
    
    static CFMutableDictionaryRef charToCodeDict = NULL;
    CGKeyCode code;
    UniChar character = c;
    CFStringRef charStr = NULL;
    
    /* Generate table of keycodes and characters. */
    if (charToCodeDict == NULL) {
        size_t i;
        charToCodeDict = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                   128,
                                                   &kCFCopyStringDictionaryKeyCallBacks,
                                                   NULL);
        if (charToCodeDict == NULL) return UINT16_MAX;
        
        /* Loop through every keycode (0 - 127) to find its current mapping. */
        for (i = 0; i < 128; ++i) {
            CFStringRef string = [self createStringForKey:(CGKeyCode)i];
            if (string != NULL) {
                CFDictionaryAddValue(charToCodeDict, string, (const void *)i);
                CFRelease(string);
            }
        }
    }
    
    charStr = CFStringCreateWithCharacters(kCFAllocatorDefault, &character, 1);
    
    /* Our values may be NULL (0), so we need to use this function. */
    if (!CFDictionaryGetValueIfPresent(charToCodeDict, charStr,
                                       (const void **)&code)) {
        code = UINT16_MAX;
    }
    
    CFRelease(charStr);
    return code;
}

- (CFStringRef)createStringForKey:(CGKeyCode)keyCode {
    
    TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardInputSource();
    CFDataRef layoutData =
    TISGetInputSourceProperty(currentKeyboard,
                              kTISPropertyUnicodeKeyLayoutData);
    const UCKeyboardLayout *keyboardLayout =
    (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
    
    UInt32 keysDown = 0;
    UniChar chars[4];
    UniCharCount realLength;
    
    UCKeyTranslate(keyboardLayout,
                   keyCode,
                   kUCKeyActionDisplay,
                   0,
                   LMGetKbdType(),
                   kUCKeyTranslateNoDeadKeysBit,
                   &keysDown,
                   sizeof(chars) / sizeof(chars[0]),
                   &realLength,
                   chars);
    CFRelease(currentKeyboard);
    return CFStringCreateWithCharacters(kCFAllocatorDefault, chars, 1);
}

- (NSString *)serialNumber {
    io_service_t platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                              
                                                              IOServiceMatching("IOPlatformExpertDevice"));
    CFStringRef serialNumberAsCFString = NULL;
    
    if (platformExpert) {
        serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, CFSTR(kIOPlatformSerialNumberKey), kCFAllocatorDefault, 0);
        IOObjectRelease(platformExpert);
    }
    
    NSString *serialNumberAsNSString = nil;
    if (serialNumberAsCFString) {
        serialNumberAsNSString = [NSString stringWithString:(__bridge NSString *)serialNumberAsCFString];
        CFRelease(serialNumberAsCFString);
    }
    
    return serialNumberAsNSString;
}


- (IBAction)btnRefreshTapped:(id)sender {
    [AppConfig getInstance].name = self.txtLaptopName.stringValue;
    [self createServerConnection];
}

#pragma mark - ServerConnectionDelegate
- (void)serverConectionReceivedMessage:(NSDictionary *)message {
    self.lblConnectedStatus.stringValue = [NSString stringWithFormat:@"%@\n%@", self.lblConnectedStatus.stringValue, message[@"message"]];
    [self writeTextToWindow:message[@"message"]];
}

@end
