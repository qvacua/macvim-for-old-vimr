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


/**
* Utility class which contains convenience class methods.
*/
@interface MMUtils : NSObject

/**
* Sets NSQuotedKeystrokeBinding and NSRepeatCountBinding to appropriate values such that VIM works.
*
* You just have to call it once when the app starts, eg in main.m or in some +initialize of some object which is
* instantiated in the main nib file.
*/
+ (void)setKeyHandlingUserDefaults;

/**
* Disable the default Cocoa "Key Bindings" since they interfere with the
* way Vim handles keyboard input.  Cocoa reads bindings from
*     /System/Library/Frameworks/AppKit.framework/Resources/
*                                                  StandardKeyBinding.dict
* and
*     ~/Library/KeyBindings/DefaultKeyBinding.dict
*
* To avoid having the user accidentally break keyboard handling (by
* modifying the latter in some unexpected way) in MacVim we load our own
* key binding dictionary from Resource/KeyBinding.plist.  We can't disable
* the bindings completely since it would break keyboard handling in
* dialogs so the our custom dictionary contains all the entries from the
* former location.
*
* It is possible to disable key bindings completely by not calling
* interpretKeyEvents: in keyDown: but this also disables key bindings used
* by certain input methods.  E.g.  Ctrl-Shift-; would no longer work in
* the Kotoeri input manager.
*
* To solve this problem we access a private API and set the key binding
* dictionary to our own custom dictionary here.  At this time Cocoa will
* have already read the above mentioned dictionaries so it (hopefully)
* won't try to change the key binding dictionary again after this point.
*/
+ (void)setVimKeybindings;

@end
