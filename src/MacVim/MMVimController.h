/* vi:set ts=8 sts=4 sw=4 ft=objc:
 *
 * VIM - Vi IMproved		by Bram Moolenaar
 *				MacVim GUI port by Bjorn Winckler
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

#import "MacVim.h"


@class MMWindowController;
@protocol MMVimControllerDelegate;


@interface MMVimController : NSObject <NSToolbarDelegate> {
    unsigned            identifier;
    BOOL                isInitialized;
    MMWindowController  *windowController;
    id                  backendProxy;
    NSMenu              *mainMenu;
    NSMutableArray      *popupMenuItems;

    // TODO: Move all toolbar code to window controller?
    NSToolbar           *toolbar;
    NSMutableDictionary *toolbarItemDict;

    int                 pid;
    NSString            *serverName;
    NSDictionary        *vimState;
    BOOL                isPreloading;
    NSDate              *creationDate;
    BOOL                hasModifiedBuffer;
}

@property (assign) id <MMVimControllerDelegate> delegate;
@property (assign) MMVimView *vimView;

- (id)initWithBackend:(id)backend pid:(int)processIdentifier;
- (unsigned)vimControllerId;
- (id)backendProxy;
- (int)pid;
- (void)setServerName:(NSString *)name;
- (NSString *)serverName;
- (MMWindowController *)windowController;
- (NSDictionary *)vimState;
- (id)objectForVimStateKey:(NSString *)key;
- (NSMenu *)mainMenu;
- (BOOL)isPreloading;
- (void)setIsPreloading:(BOOL)yn;
- (BOOL)hasModifiedBuffer;
- (NSDate *)creationDate;
- (void)cleanup;
- (void)dropFiles:(NSArray *)filenames forceOpen:(BOOL)force;
- (void)file:(NSString *)filename draggedToTabAtIndex:(NSUInteger)tabIndex;
- (void)filesDraggedToTabBar:(NSArray *)filenames;
- (void)dropString:(NSString *)string;
- (void)passArguments:(NSDictionary *)args;
- (void)sendMessage:(int)msgid data:(NSData *)data;
- (BOOL)sendMessageNow:(int)msgid data:(NSData *)data
               timeout:(NSTimeInterval)timeout;
- (void)addVimInput:(NSString *)string;
- (NSString *)evaluateVimExpression:(NSString *)expr;
- (void)processInputQueue:(NSArray *)queue;

- (BOOL)tellBackend:(id)obj;
- (BOOL)sendDialogReturnToBackend:(id)obj;
@end
