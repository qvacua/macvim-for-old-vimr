/* vi:set ts=8 sts=4 sw=4 ft=objc:
 *
 * VIM - Vi IMproved		by Bram Moolenaar
 *				MacVim GUI port by Bjorn Winckler
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

//
// The following enum lists all messages that are passed between MacVim and
// Vim.  These can be sent in processInput:data: and in processCommandQueue:.
//

// NOTE! This array must be updated whenever the enum below changes!
extern char *MessageStrings[];

enum {
    OpenWindowMsgID = 1,    // NOTE: FIRST IN ENUM MUST BE 1
    KeyDownMsgID,
    BatchDrawMsgID,
    SelectTabMsgID,
    CloseTabMsgID,
    AddNewTabMsgID,
    DraggedTabMsgID,
    DraggedTabReplyMsgID,
    UpdateTabBarMsgID,
    ShowTabBarMsgID,
    HideTabBarMsgID,
    SetTextRowsMsgID,
    SetTextColumnsMsgID,
    SetTextDimensionsMsgID,
    LiveResizeMsgID,
    SetTextDimensionsReplyMsgID,
    SetWindowTitleMsgID,
    ScrollWheelMsgID,
    MouseDownMsgID,
    MouseUpMsgID,
    MouseDraggedMsgID,
    FlushQueueMsgID,
    AddMenuMsgID,
    AddMenuItemMsgID,
    RemoveMenuItemMsgID,
    EnableMenuItemMsgID,
    ExecuteMenuMsgID,
    ShowToolbarMsgID,
    ToggleToolbarMsgID,
    CreateScrollbarMsgID,
    DestroyScrollbarMsgID,
    ShowScrollbarMsgID,
    SetScrollbarPositionMsgID,
    SetScrollbarThumbMsgID,
    ScrollbarEventMsgID,
    SetFontMsgID,
    SetWideFontMsgID,
    VimShouldCloseMsgID,
    SetDefaultColorsMsgID,
    ExecuteActionMsgID,
    DropFilesMsgID,
    DropStringMsgID,
    ShowPopupMenuMsgID,
    GotFocusMsgID,
    LostFocusMsgID,
    MouseMovedMsgID,
    SetMouseShapeMsgID,
    AdjustLinespaceMsgID,
    ActivateMsgID,
    SetServerNameMsgID,
    EnterFullScreenMsgID,
    LeaveFullScreenMsgID,
    SetBuffersModifiedMsgID,
    AddInputMsgID,
    SetPreEditPositionMsgID,
    TerminateNowMsgID,
    XcodeModMsgID,
    EnableAntialiasMsgID,
    DisableAntialiasMsgID,
    SetVimStateMsgID,
    SetDocumentFilenameMsgID,
    OpenWithArgumentsMsgID,
    CloseWindowMsgID,
    SetFullScreenColorMsgID,
    ShowFindReplaceDialogMsgID,
    FindReplaceMsgID,
    ActivateKeyScriptMsgID,
    DeactivateKeyScriptMsgID,
    EnableImControlMsgID,
    DisableImControlMsgID,
    ActivatedImMsgID,
    DeactivatedImMsgID,
    BrowseForFileMsgID,
    ShowDialogMsgID,
    NetBeansMsgID,
    SetMarkedTextMsgID,
    ZoomMsgID,
    SetWindowPositionMsgID,
    DeleteSignMsgID,
    SetTooltipMsgID,
    SetTooltipDelayMsgID,
    GestureMsgID,
    AddToMRUMsgID,
    BackingPropertiesChangedMsgID,
    LastMsgID   // NOTE: MUST BE LAST MESSAGE IN ENUM!
};

enum {
    // These values are chosen so that the min text view size is not too small
    // with the default font (they only affect resizing with the mouse, you can
    // still use e.g. ":set lines=2" to go below these values).
    MMMinRows = 4,
    MMMinColumns = 30
};

// Enum for MMOpenLayoutKey (first 4 must match WIN_* defines in main.c)
enum {
    MMLayoutArglist = 0,
    MMLayoutHorizontalSplit = 1,
    MMLayoutVerticalSplit = 2,
    MMLayoutTabs = 3,
    MMLayoutWindows = 4,
};

enum {
    ClearAllDrawType = 1,
    ClearBlockDrawType,
    DeleteLinesDrawType,
    DrawStringDrawType,
    InsertLinesDrawType,
    DrawCursorDrawType,
    SetCursorPosDrawType,
    DrawInvertedRectDrawType,
    DrawSignDrawType,
};

enum {
    MMInsertionPointBlock,
    MMInsertionPointHorizontal,
    MMInsertionPointVertical,
    MMInsertionPointHollow,
    MMInsertionPointVerticalRight,
};

enum {
    MMGestureSwipeLeft,
    MMGestureSwipeRight,
    MMGestureSwipeUp,
    MMGestureSwipeDown,
};

enum {
    MMTabLabel = 0,
    MMTabToolTip,
    MMTabInfoCount
};

enum {
    MMRendererDefault = 0,
    MMRendererATSUI,
    MMRendererCoreText
};
