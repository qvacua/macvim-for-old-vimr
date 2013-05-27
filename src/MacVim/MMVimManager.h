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
#import "MMAppProtocol.h"


@class MMVimController;


@interface MMVimManager : NSObject <MMAppProtocol>

@property (readonly) NSArray *vimControllers;
@property (readonly) NSArray *cachedVimControllers;

- (BOOL)processesAboutToLaunch;
- (void)terminateAllVimProcesses;
- (NSUInteger)countOfVimControllers;
- (NSEnumerator *)enumeratorOfVimControllers;
- (MMVimController *)objectInVimControllersAtIndex:(NSUInteger)index;

- (NSUInteger)countOfCachedVimControllers;
- (NSEnumerator *)enumeratorOfCachedVimControllers;
- (MMVimController *)objectInCachedVimControllersAtIndex:(NSUInteger)index;

- (void)setUp;
- (void)rebuildPreloadCache;
- (void)toggleQuickStart;
- (BOOL)openVimController:(MMVimController *)vc withArguments:(NSDictionary *)arguments;
- (MMVimController *)getVimController;
- (void)removeVimController:(id)controller;
- (void)cleanUp;

- (void)handleFSEvent;

- (int)launchVimProcessWithArguments:(NSArray *)args workingDirectory:(NSString *)cwd;
- (BOOL)readAndResetLastVimControllerHasArgs;
- (int)maxPreloadCacheSize;
+ (MMVimManager *)sharedManager;

@end