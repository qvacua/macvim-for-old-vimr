/* vi:set ts=8 sts=4 sw=4 ft=objc:
 *
 * VIM - Vi IMproved		by Bram Moolenaar
 *				MacVim GUI port by Bjorn Winckler
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */
/*
 * MacVim.m:  Code shared between Vim and MacVim.
 */

#import "MacVim.h"


// Argument used to stop MacVim from opening an empty window on startup
// (techincally this is a user default but should not be used as such).
NSString *MMNoWindowKey = @"MMNoWindow";

NSString *MMAutosaveRowsKey    = @"MMAutosaveRows";
NSString *MMAutosaveColumnsKey = @"MMAutosaveColumns";

// Vim find pasteboard type (string contains Vim regex patterns)
NSString *VimFindPboardType = @"VimFindPboardType";

