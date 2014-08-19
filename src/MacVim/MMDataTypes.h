/**
 * Tae Won Ha — @hataewon
 *
 * http://taewon.de
 * http://qvacua.com
 *
 * See LICENSE
 */

#import <Foundation/Foundation.h>


@interface MMBuffer : NSObject

@property (readonly) NSInteger number;
@property (copy, readonly) NSString *fileName;
@property (readonly) BOOL modified;

- (instancetype)initWithNumber:(NSInteger)number fileName:(NSString *)fileName modified:(BOOL)modified;
- (NSString *)description;
- (BOOL)isEqual:(id)other;
- (BOOL)isEqualToBuffer:(MMBuffer *)buffer;
- (NSUInteger)hash;

@end


@interface MMVimWindow : NSObject

@property (strong, readonly) MMBuffer *buffer;
@property BOOL currentWindow;

- (instancetype)initWithBuffer:(MMBuffer *)buffer;
- (NSString *)description;

@end


@interface MMTabPage : NSObject

@property (strong, readonly) NSArray *vimWindows;

- (instancetype)initWithVimWindows:(NSArray *)vimWindows;
- (MMBuffer *)currentBuffer;
- (NSArray *)buffers;
- (NSString *)description;

@end
