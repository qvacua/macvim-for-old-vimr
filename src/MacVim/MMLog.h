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
#import <asl.h>


// Logging related functions and macros.
//
// This is a very simplistic logging facility built on top of ASL.  Two user
// defaults allow for changing the local log filter level (MMLogLevel) and
// whether logs should be sent to stderr (MMLogToStdErr).  (These user defaults
// are only checked during startup.)  The default is to block level 6 (info)
// and 7 (debug) logs and _not_ to send logs to stderr.  Apart from this
// "syslog" (see "man syslog") can be used to modify the ASL filters (it is
// currently not possible to change the local filter at runtime).  For example:
//   Enable all logs to reach the ASL database (by default 'debug' and 'info'
//   are filtered out, see "man syslogd"):
//     $ sudo syslog -c syslogd -d
//   Reset the ASL database filter:
//     $ sudo syslog -c syslogd off
//   Change the master filter to block logs less severe than errors:
//     $ sudo syslog -c 0 -e
//   Change per-process filter for running MacVim process to block logs less
//   severe than warnings:
//     $ syslog -c MacVim -w
//
// Note that there are four ASL filters:
//   1) The ASL database filter (syslog -c syslogd ...)
//   2) The master filter (syslog -c 0 ...)
//   3) The per-process filter (syslog -c PID ...)
//   4) The local filter (MMLogLevel)
//
// To view the logs, either use "Console.app" or the "syslog" command:
//   $ syslog -w | grep Vim
// To get the logs to show up in Xcode enable the MMLogToStdErr user default.

extern NSString *MMLogLevelKey;
extern NSString *MMLogToStdErrKey;
extern NSString *MMLogToStdOutKey;

extern int ASLogLevel;

extern void ASLInit();

#define ASLog(level, fmt, ...) \
    if (level <= ASLogLevel) { \
        asl_log(NULL, NULL, level, "%s@%d: %s", \
            __PRETTY_FUNCTION__, __LINE__, \
            [[NSString stringWithFormat:fmt, ##__VA_ARGS__] UTF8String]); \
    }

// Note: These macros are used like ASLogErr(@"text num=%d", 42).  Objective-C
// style specifiers (%@) are supported.
#define ASLogCrit(fmt, ...)   ASLog(ASL_LEVEL_CRIT,    fmt, ##__VA_ARGS__)
#define ASLogErr(fmt, ...)    ASLog(ASL_LEVEL_ERR,     fmt, ##__VA_ARGS__)
#define ASLogWarn(fmt, ...)   ASLog(ASL_LEVEL_WARNING, fmt, ##__VA_ARGS__)
#define ASLogNotice(fmt, ...) ASLog(ASL_LEVEL_NOTICE,  fmt, ##__VA_ARGS__)
#define ASLogInfo(fmt, ...)   ASLog(ASL_LEVEL_INFO,    fmt, ##__VA_ARGS__)
#define ASLogDebug(fmt, ...)  ASLog(ASL_LEVEL_DEBUG,   fmt, ##__VA_ARGS__)
#define ASLogTmp(fmt, ...)    ASLog(ASL_LEVEL_NOTICE,  fmt, ##__VA_ARGS__)
