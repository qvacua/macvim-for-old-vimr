//
//  MMAppDelegate.h
//  MinimalMacVim
//
//  Created by Tae Won Ha on 26/01/14.
//
//

#import <Cocoa/Cocoa.h>

@interface MMAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate, MMVimManagerDelegateProtocol, MMVimControllerDelegate>

@property (assign) IBOutlet NSWindow *window;

@end
