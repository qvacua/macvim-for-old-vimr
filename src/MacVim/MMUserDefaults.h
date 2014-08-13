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


// TODO: Remove this when the inline IM code has been tested
#define INCLUDE_OLD_IM_CODE


extern NSString *MMAutosaveRowsKey;
extern NSString *MMAutosaveColumnsKey;

extern NSString *MMCellWidthMultiplierKey;
extern NSString *MMNoFontSubstitutionKey;
extern NSString *MMBaselineOffsetKey;
extern NSString *MMTextInsetRightKey;
extern NSString *MMTextInsetBottomKey;
extern NSString *MMTextInsetLeftKey;
extern NSString *MMTextInsetTopKey;
extern NSString *MMTranslateCtrlClickKey;
extern NSString *MMLoginShellKey;
extern NSString *MMPreloadCacheSizeKey;
extern NSString *MMLoginShellCommandKey;
extern NSString *MMLoginShellArgumentKey;
extern NSString *MMTypesetterKey;
extern NSString *MMOpenLayoutKey;
extern NSString *MMVerticalSplitKey;
extern NSString *MMDialogsTrackPwdKey;
extern NSString *MMTabMinWidthKey;
extern NSString *MMTabMaxWidthKey;
extern NSString *MMTabOptimumWidthKey;
extern NSString *MMShowAddTabButtonKey;
extern NSString *MMRendererKey;
#ifdef INCLUDE_OLD_IM_CODE
extern NSString *MMUseInlineImKey;
#endif // INCLUDE_OLD_IM_CODE
