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


@class MMTabPage;
@class MMBuffer;

/**
* This is the protocol MMBackend implements.
*
* Only processInput:data: is allowed to cause state changes in Vim; all other
* messages should only read the Vim state.  (Note that setDialogReturn: is an
* exception to this rule; there really is no other way to deal with dialogs
* since they work with callbacks, so we cannot wait for them to return.)
*
* Be careful with messages with return type other than 'oneway void' -- there
* is a reply timeout set in MMAppController, if a message fails to get a
* response within the given timeout an exception will be thrown.  Use
* @try/@catch/@finally to deal with timeouts.
*/
@protocol MMBackendProtocol

- (oneway void)processInput:(int)msgid data:(in bycopy NSData *)data;
- (oneway void)setDialogReturn:(in bycopy id)obj;
- (NSString *)evaluateExpression:(in bycopy NSString *)expr;
- (id)evaluateExpressionCocoa:(in bycopy NSString *)expr errorString:(out bycopy NSString **)errstr;
- (BOOL)starRegisterToPasteboard:(byref NSPasteboard *)pboard;
- (oneway void)acknowledgeConnection;

- (NSArray *)tabs;
- (NSArray *)buffers;
- (MMTabPage *)currentTab;
- (MMBuffer *)currentBuffer;
- (void)openWindowWithUrl:(NSURL *)url;

@end


/**
* The Vim client protocol (implemented by MMBackend).
*
* The client needs to keep track of server replies.  Take a look at MMBackend
* if you want to implement this protocol in another program.
*/
@protocol MMVimServerProtocol;


@protocol MMVimClientProtocol

- (oneway void)addReply:(in bycopy NSString *)reply server:(in byref id <MMVimServerProtocol>)server;
@end


/**
* The Vim server protocol (implemented by MMBackend).
*
* Note that addInput:client: is not asynchronous, because otherwise Vim might
* quit before the message has been passed (e.g. if --remote was used on the
* command line).
*/
@protocol MMVimServerProtocol

- (void)addInput:(in bycopy NSString *)input client:(in byref id <MMVimClientProtocol>)client;
- (NSString *)evaluateExpression:(in bycopy NSString *)expr client:(in byref id <MMVimClientProtocol>)client;

@end
