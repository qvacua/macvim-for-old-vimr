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

@property NSInteger number;
@property (copy) NSString *fileName;

- (instancetype)initWithNumber:(NSInteger)number fileName:(NSString *)fileName;
- (NSString *)description;

@end

@interface MMTabPage : NSObject

@property (strong) MMBuffer *buffer;

- (instancetype)initWithBuffer:(MMBuffer *)buffer;
- (NSString *)description;

@end
