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
  [_fileName release];
  [super dealloc];
}

- (BOOL)isEqual:(id)other {
  if (other == self)
    return YES;
  if (!other || ![[other class] isEqual:[self class]])
    return NO;

  return [self isEqualToBuffer:other];
}

- (BOOL)isEqualToBuffer:(MMBuffer *)buffer {
  if (self == buffer)
    return YES;
  if (buffer == nil)
    return NO;
  if (self.fileName != buffer.fileName && ![self.fileName isEqualToString:buffer.fileName])
    return NO;
  if (self.number != buffer.number)
    return NO;
  return YES;
}

- (NSUInteger)hash {
  NSUInteger hash = [self.fileName hash];
  hash = hash * 31u + self.number;
  return hash;
}

@end


@implementation MMVimWindow

- (instancetype)initWithBuffer:(MMBuffer *)buffer {
  self = [super init];
  if (self) {
    _buffer = [buffer retain];
    _currentWindow = NO;
  }

  return self;
}

- (void)dealloc {
  [_buffer release];
  [super dealloc];
}

- (NSString *)description {
  NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
  [description appendFormat:@"self.buffer=%@", self.buffer];
  [description appendString:@">"];
  return description;
}

@end


@implementation MMTabPage

- (instancetype)initWithVimWindows:(NSArray *)vimWindows {
  self = [super init];
  if (self) {
    _vimWindows = [vimWindows retain];
  }

  return self;
}

- (MMBuffer *)currentBuffer {
  for (MMVimWindow *vimWindow in _vimWindows) {
    if (vimWindow.currentWindow) {
      return vimWindow.buffer;
    }
  }

  return nil;
}

- (NSArray *)buffers {
  NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:_vimWindows.count];
  for (MMVimWindow *vimWindow in _vimWindows) {
    [result addObject:vimWindow.buffer];
  }

  return [result autorelease];
}

- (NSString *)description {
  NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
  [description appendFormat:@"self.vimWindow=%@", self.vimWindows];
  [description appendString:@">"];
  return description;
}

- (void)dealloc {
  [_vimWindows release];
  [super dealloc];
}

@end
