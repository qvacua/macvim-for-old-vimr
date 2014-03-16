/**
 * Tae Won Ha — @hataewon
 *
 * http://taewon.de
 * http://qvacua.com
 *
 * See LICENSE
 */

#import "MMDataTypes.h"

@implementation MMBuffer

- (instancetype)initWithNumber:(NSInteger)number fileName:(NSString *)fileName modified:(BOOL)modified {
    self = [super init];
    if (self) {
        _number = number;
        _fileName = [fileName copy];
        _modified = modified;
    }

    return self;
}

- (NSString *)description {
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.number=%li", self.number];
    [description appendFormat:@", self.fileName=%@", self.fileName];
    [description appendFormat:@", self.modified=%d", self.modified];
    [description appendString:@">"];
    return description;
}

- (void)dealloc {
    self.fileName = nil;
    [super dealloc];
}

@end

@implementation MMTabPage

- (instancetype)initWithBuffer:(MMBuffer *)buffer {
    self = [super init];
    if (self) {
        _buffer = [buffer retain];
    }

    return self;
}

- (NSString *)description {
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.buffer=%@", self.buffer];
    [description appendString:@">"];
    return description;
}

- (void)dealloc {
    [_buffer release];
    [super dealloc];
}

@end
