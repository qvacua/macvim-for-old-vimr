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


typedef struct {
    unsigned length;        // length of row in unichars
    int col;                // last column accessed (in this row)
    unsigned colOffset;     // offset of 'col' from start of row (in unichars)
} MMRowCacheEntry;


/*
 * MMTextStorage
 *
 * Text rendering related code.
 *
 * Note that:
 * - There are exactly 'actualRows' number of rows
 * - Each row is terminated by an EOL character ('\n')
 * - Each row must cover exactly 'actualColumns' display cells
 * - The attribute "MMWideChar" denotes a character that covers two cells, a
 *   character without this attribute covers one cell
 * - Unicode line (U+2028) and paragraph (U+2029) terminators are considered
 *   invalid and are replaced by spaces
 * - Spaces are used to fill out blank spaces
 *
 * In order to locate a (row,col) pair it is in general necessary to search one
 * character at a time.  To speed things up we cache the length of each row, as
 * well as the offset of the last column searched within each row.
 *
 * If each character in the text storage has length 1 and is not wide, then
 * there is no need to search for a (row, col) pair since it can easily be
 * computed.
 */
@interface MMTextStorage : NSTextStorage {
    NSMutableAttributedString *attribString;
    int maxRows, maxColumns;
    int actualRows, actualColumns;
    NSAttributedString *emptyRowString;
    NSFont *font;
    NSFont *boldFont;
    NSFont *italicFont;
    NSFont *boldItalicFont;
    NSFont *fontWide;
    NSFont *boldFontWide;
    NSFont *italicFontWide;
    NSFont *boldItalicFontWide;
    NSColor *defaultBackgroundColor;
    NSColor *defaultForegroundColor;
    NSSize cellSize;
    float linespace;
    MMRowCacheEntry *rowCache;
    BOOL characterEqualsColumn;
}

- (NSString *)string;
- (NSDictionary *)attributesAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)aRange;
- (void)replaceCharactersInRange:(NSRange)aRange withString:(NSString *)aString;
- (void)setAttributes:(NSDictionary *)attributes range:(NSRange)aRange;

- (int)maxRows;
- (int)maxColumns;
- (int)actualRows;
- (int)actualColumns;
- (float)linespace;
- (void)setLinespace:(float)newLinespace;
- (void)getMaxRows:(int *)rows columns:(int *)cols;
- (void)setMaxRows:(int)rows columns:(int)cols;
- (void)drawString:(NSString *)string atRow:(int)row column:(int)col cells:(int)cells withFlags:(int)flags
   foregroundColor:(NSColor *)fg backgroundColor:(NSColor *)bg specialColor:(NSColor *)sp;
- (void)deleteLinesFromRow:(int)row lineCount:(int)count scrollBottom:(int)bottom left:(int)left right:(int)right color:(NSColor *)color;
- (void)insertLinesAtRow:(int)row lineCount:(int)count scrollBottom:(int)bottom left:(int)left right:(int)right color:(NSColor *)color;
- (void)clearBlockFromRow:(int)row1 column:(int)col1 toRow:(int)row2 column:(int)col2 color:(NSColor *)color;
- (void)clearAll;
- (void)setDefaultColorsBackground:(NSColor *)bgColor foreground:(NSColor *)fgColor;
- (void)setFont:(NSFont *)newFont;
- (void)setWideFont:(NSFont *)newFont;
- (NSFont *)font;
- (NSFont *)fontWide;
- (NSColor *)defaultBackgroundColor;
- (NSColor *)defaultForegroundColor;
- (NSSize)size;
- (NSSize)cellSize;
- (NSRect)rectForRowsInRange:(NSRange)range;
- (NSRect)rectForColumnsInRange:(NSRange)range;
- (NSUInteger)characterIndexForRow:(int)row column:(int)col;
- (BOOL)resizeToFitSize:(NSSize)size;
- (NSSize)fitToSize:(NSSize)size;
- (NSSize)fitToSize:(NSSize)size rows:(int *)rows columns:(int *)columns;
- (NSRect)boundingRectForCharacterAtRow:(int)row column:(int)col;
- (MMRowCacheEntry *)rowCache;

@end
