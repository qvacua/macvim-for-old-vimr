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

/**
* Utility class which contains convenience class methods.
*/
@interface MMUtils : NSObject {

}

/**
* Sets NSQuotedKeystrokeBinding and NSRepeatCountBinding to appropriate values such that VIM works.
*
* You just have to call it once when the app starts, eg in main.m or in some +initialize of some object which is
* instantiated in the main nib file.
*/
+ (void)setKeyHandlingUserDefaults;

@end
