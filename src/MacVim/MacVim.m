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


char *MessageStrings[] = 
{
    "INVALID MESSAGE ID",
    "OpenWindowMsgID",
    "KeyDownMsgID",
    "BatchDrawMsgID",
    "SelectTabMsgID",
    "CloseTabMsgID",
    "AddNewTabMsgID",
    "DraggedTabMsgID",
    "UpdateTabBarMsgID",
    "ShowTabBarMsgID",
    "HideTabBarMsgID",
    "SetTextRowsMsgID",
    "SetTextColumnsMsgID",
    "SetTextDimensionsMsgID",
    "LiveResizeMsgID",
    "SetTextDimensionsReplyMsgID",
    "SetWindowTitleMsgID",
    "ScrollWheelMsgID",
    "MouseDownMsgID",
    "MouseUpMsgID",
    "MouseDraggedMsgID",
    "FlushQueueMsgID",
    "AddMenuMsgID",
    "AddMenuItemMsgID",
    "RemoveMenuItemMsgID",
    "EnableMenuItemMsgID",
    "ExecuteMenuMsgID",
    "ShowToolbarMsgID",
    "ToggleToolbarMsgID",
    "CreateScrollbarMsgID",
    "DestroyScrollbarMsgID",
    "ShowScrollbarMsgID",
    "SetScrollbarPositionMsgID",
    "SetScrollbarThumbMsgID",
    "ScrollbarEventMsgID",
    "SetFontMsgID",
    "SetWideFontMsgID",
    "VimShouldCloseMsgID",
    "SetDefaultColorsMsgID",
    "ExecuteActionMsgID",
    "DropFilesMsgID",
    "DropStringMsgID",
    "ShowPopupMenuMsgID",
    "GotFocusMsgID",
    "LostFocusMsgID",
    "MouseMovedMsgID",
    "SetMouseShapeMsgID",
    "AdjustLinespaceMsgID",
    "ActivateMsgID",
    "SetServerNameMsgID",
    "EnterFullScreenMsgID",
    "LeaveFullScreenMsgID",
    "SetBuffersModifiedMsgID",
    "AddInputMsgID",
    "SetPreEditPositionMsgID",
    "TerminateNowMsgID",
    "XcodeModMsgID",
    "EnableAntialiasMsgID",
    "DisableAntialiasMsgID",
    "SetVimStateMsgID",
    "SetDocumentFilenameMsgID",
    "OpenWithArgumentsMsgID",
    "CloseWindowMsgID",
    "SetFullScreenColorMsgID",
    "ShowFindReplaceDialogMsgID",
    "FindReplaceMsgID",
    "ActivateKeyScriptMsgID",
    "DeactivateKeyScriptMsgID",
    "EnableImControlMsgID",
    "DisableImControlMsgID",
    "ActivatedImMsgID",
    "DeactivatedImMsgID",
    "BrowseForFileMsgID",
    "ShowDialogMsgID",
    "NetBeansMsgID",
    "SetMarkedTextMsgID",
    "ZoomMsgID",
    "SetWindowPositionMsgID",
    "DeleteSignMsgID",
    "SetTooltipMsgID",
    "SetTooltipDelayMsgID",
    "GestureMsgID",
    "AddToMRUMsgID",
    "END OF MESSAGE IDs"     // NOTE: Must be last!
};




// Argument used to stop MacVim from opening an empty window on startup
// (techincally this is a user default but should not be used as such).
NSString *MMNoWindowKey = @"MMNoWindow";

NSString *MMAutosaveRowsKey    = @"MMAutosaveRows";
NSString *MMAutosaveColumnsKey = @"MMAutosaveColumns";
NSString *MMRendererKey	       = @"MMRenderer";

// Vim find pasteboard type (string contains Vim regex patterns)
NSString *VimFindPboardType = @"VimFindPboardType";

int ASLogLevel = ASL_LEVEL_NOTICE;



// Create a string holding the labels of all messages in message queue for
// debugging purposes (condense some messages since there may typically be LOTS
// of them on a queue).
    NSString *
debugStringForMessageQueue(NSArray *queue)
{
    NSMutableString *s = [NSMutableString new];
    unsigned i, count = [queue count];
    int item = 0, menu = 0, enable = 0, remove = 0;
    int sets = 0, sett = 0, shows = 0, cres = 0, dess = 0;
    for (i = 0; i < count; i += 2) {
        NSData *value = [queue objectAtIndex:i];
        int msgid = *((int*)[value bytes]);
        if (msgid < 1 || msgid >= LastMsgID)
            continue;
        if (msgid == AddMenuItemMsgID) ++item;
        else if (msgid == AddMenuMsgID) ++menu;
        else if (msgid == EnableMenuItemMsgID) ++enable;
        else if (msgid == RemoveMenuItemMsgID) ++remove;
        else if (msgid == SetScrollbarPositionMsgID) ++sets;
        else if (msgid == SetScrollbarThumbMsgID) ++sett;
        else if (msgid == ShowScrollbarMsgID) ++shows;
        else if (msgid == CreateScrollbarMsgID) ++cres;
        else if (msgid == DestroyScrollbarMsgID) ++dess;
        else [s appendFormat:@"%s ", MessageStrings[msgid]];
    }
    if (item > 0) [s appendFormat:@"AddMenuItemMsgID(%d) ", item];
    if (menu > 0) [s appendFormat:@"AddMenuMsgID(%d) ", menu];
    if (enable > 0) [s appendFormat:@"EnableMenuItemMsgID(%d) ", enable];
    if (remove > 0) [s appendFormat:@"RemoveMenuItemMsgID(%d) ", remove];
    if (sets > 0) [s appendFormat:@"SetScrollbarPositionMsgID(%d) ", sets];
    if (sett > 0) [s appendFormat:@"SetScrollbarThumbMsgID(%d) ", sett];
    if (shows > 0) [s appendFormat:@"ShowScrollbarMsgID(%d) ", shows];
    if (cres > 0) [s appendFormat:@"CreateScrollbarMsgID(%d) ", cres];
    if (dess > 0) [s appendFormat:@"DestroyScrollbarMsgID(%d) ", dess];

    return [s autorelease];
}
