/* vi:set ts=8 sts=4 sw=4 ft=objc:
 *
 * VIM - Vi IMproved		by Bram Moolenaar
 *				MacVim GUI port by Bjorn Winckler
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

#import <Foundation/Foundation.h>


@protocol MMBackendProtocol;


/**
* This is the protocol MMAppController implements.
*
* It handles connections between MacVim and Vim and communication from Vim to
* MacVim.
*
* Do not add methods to this interface without a _very_ good reason (if
* possible, instead add a new message to the *MsgID enum below and pass it via
* processInput:forIdentifier).  Methods should not modify the state directly
* but should instead delay any potential modifications (see
* connectBackend:pid: and processInput:forIdentifier:).
*/
@protocol MMAppProtocol

- (unsigned)connectBackend:(byref in id <MMBackendProtocol>)proxy pid:(int)pid;
- (oneway void)processInput:(in bycopy NSArray *)queue forIdentifier:(unsigned)identifier;
- (NSArray *)serverList;

@end