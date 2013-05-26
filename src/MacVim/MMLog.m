/* vi:set ts=8 sts=4 sw=4 ft=objc:
 *
 * VIM - Vi IMproved		by Bram Moolenaar
 *				MacVim GUI port by Bjorn Winckler
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

#import "MMLog.h"


NSString *MMLogLevelKey = @"MMLogLevel";
NSString *MMLogToStdErrKey = @"MMLogToStdErr";

int ASLogLevel = ASL_LEVEL_NOTICE;

void
ASLInit() {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

    // Allow for changing the log level via user defaults.  If no key is found
    // the default log level will be used (which for ASL is to log everything
    // up to ASL_LEVEL_NOTICE).  This key is an integer which corresponds to
    // the ASL_LEVEL_* macros (0 is most severe, 7 is debug level).
    id logLevelObj = [ud objectForKey:MMLogLevelKey];
    if (logLevelObj) {
        int logLevel = [logLevelObj intValue];
        if (logLevel < 0) logLevel = 0;
        if (logLevel > ASL_LEVEL_DEBUG) logLevel = ASL_LEVEL_DEBUG;

        ASLogLevel = logLevel;
        asl_set_filter(NULL, ASL_FILTER_MASK_UPTO(logLevel));
    }

    // Allow for changing whether a copy of each log should be sent to stderr
    // (this defaults to NO if this key is missing in the user defaults
    // database).  The above filter mask is applied to logs going to stderr,
    // contrary to how "vanilla" ASL works.
    BOOL logToStdErr = [ud boolForKey:MMLogToStdErrKey];
    if (logToStdErr)
        asl_add_log_file(NULL, 2);  // The file descriptor for stderr is 2
}
