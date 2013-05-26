/* vi:set ts=8 sts=4 sw=4 ft=objc:
 *
 * VIM - Vi IMproved		by Bram Moolenaar
 *				MacVim GUI port by Bjorn Winckler
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

enum {
    // These values are chosen so that the min text view size is not too small
    // with the default font (they only affect resizing with the mouse, you can
    // still use e.g. ":set lines=2" to go below these values).
    MMMinRows = 4,
    MMMinColumns = 30
};