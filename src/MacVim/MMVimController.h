/* vi:set ts=8 sts=4 sw=4 ft=objc:
 *
 * VIM - Vi IMproved		by Bram Moolenaar
 *				MacVim GUI port by Bjorn Winckler
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */


@class MMWindowController;
@class MMVimView;
@protocol MMVimControllerDelegate;
@class MMTabPage;
@class MMBuffer;


/**
* MMVimController
*
* Coordinates input/output to/from backend.  A MMVimController sends input
* directly to a MMBackend, but communication from MMBackend to MMVimController
* goes via MMAppController so that it can coordinate all incoming distributed
* object messages.
*
* MMVimController does not deal with visual presentation.  Essentially it
* should be able to run with no window present.
*
* Output from the backend is received in processInputQueue: (this message is
* called from MMAppController so it is not a DO call).  Input is sent to the
* backend via sendMessage:data: or addVimInput:.  The latter allows execution
* of arbitrary strings in the Vim process, much like the Vim script function
* remote_send() does.  The messages that may be passed between frontend and
* backend are defined in an enum in MacVim.h.
*/
@interface MMVimController : NSObject {
    unsigned            identifier;
    BOOL                isInitialized;
    id                  backendProxy;
    NSMenu              *mainMenu;
    NSMutableArray      *popupMenuItems;

    int                 pid;
    NSString            *serverName;
    NSDictionary        *vimState;
    BOOL                isPreloading;
    NSDate              *creationDate;
    BOOL                hasModifiedBuffer;
}

@property (assign) id <MMVimControllerDelegate> delegate;
@property (readonly) MMVimView *vimView;

- (id)initWithBackend:(id)backend pid:(int)processIdentifier;
- (unsigned)vimControllerId;
- (id)backendProxy;
- (int)pid;
- (void)setServerName:(NSString *)name;
- (NSString *)serverName;
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
- (BOOL)sendMessageNow:(int)msgid data:(NSData *)data timeout:(NSTimeInterval)timeout;
- (void)addVimInput:(NSString *)string;
- (NSString *)evaluateVimExpression:(NSString *)expr;
- (void)processInputQueue:(NSArray *)queue;

- (MMTabPage *)currentTab;
- (MMBuffer *)currentBuffer;
- (NSArray *)tabs;
- (NSArray *)buffers;
- (void)gotoBufferWithUrl:(NSURL *)url;

- (BOOL)tellBackend:(id)obj;
- (BOOL)sendDialogReturnToBackend:(id)obj;

@end
