/* vi:set ts=8 sts=4 sw=4 ft=objc:
 *
 * VIM - Vi IMproved		by Bram Moolenaar
 *				MacVim GUI port by Bjorn Winckler
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

#import <Cocoa/Cocoa.h>
#import "MacVim.h"
#import "MMVimManagerDelegateProtocol.h"


@class MMWindowController;
@class MMVimController;
@class MMVimManager;


@interface MMAppController : NSObject <MMVimManagerDelegateProtocol> {
    NSString            *openSelectionString;
    NSMenu              *defaultMainMenu;
    NSMenuItem          *appMenuItemTemplate;
    NSMenuItem          *recentFilesMenuItem;
    BOOL                shouldActivateWhenNextWindowOpens;
    MMVimManager *vimManager;
}

+ (MMAppController *)sharedInstance;
- (NSMenu *)defaultMainMenu;
- (NSMenuItem *)appMenuItemTemplate;
- (MMVimController *)keyVimController;
- (void)windowControllerWillOpen:(MMWindowController *)windowController;
- (void)setMainMenu:(NSMenu *)mainMenu;
- (NSArray *)filterOpenFiles:(NSArray *)filenames;
- (BOOL)openFiles:(NSArray *)filenames withArguments:(NSDictionary *)args;

- (IBAction)newWindow:(id)sender;
- (IBAction)newWindowAndActivate:(id)sender;
- (IBAction)fileOpen:(id)sender;
- (IBAction)selectNextWindow:(id)sender;
- (IBAction)selectPreviousWindow:(id)sender;
- (IBAction)orderFrontPreferencePanel:(id)sender;
- (IBAction)openWebsite:(id)sender;
- (IBAction)showVimHelp:(id)sender;
- (IBAction)zoomAll:(id)sender;

@end
