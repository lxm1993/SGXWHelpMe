// Software License Agreement (BSD License)
//
// Copyright (c) 2010-2014, Deusty, LLC
// All rights reserved.
//
// Redistribution and use of this software in source and binary forms,
// with or without modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
//
// * Neither the name of Deusty nor the names of its contributors may be used
//   to endorse or promote products derived from this software without specific
//   prior written permission of Deusty, LLC.

#import "SGTTYLogger.h"

#import <unistd.h>
#import <sys/uio.h>

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// We probably shouldn't be using SGLog() statements within the SGLog implementation.
// But we still want to leave our log statements for any future debugging,
// and to allow other developers to trace the implementation (which is a great learning tool).
//
// So we use primitive logging macros around NSLog.
// We maintain the NS prefix on the macros to be explicit about the fact that we're using NSLog.

#define SG_LOG_LEVEL 2

#define NSLogError(frmt, ...)    do{ if(SG_LOG_LEVEL >= 1) NSLog((frmt), ##__VA_ARGS__); } while(0)
#define NSLogWarn(frmt, ...)     do{ if(SG_LOG_LEVEL >= 2) NSLog((frmt), ##__VA_ARGS__); } while(0)
#define NSLogInfo(frmt, ...)     do{ if(SG_LOG_LEVEL >= 3) NSLog((frmt), ##__VA_ARGS__); } while(0)
#define NSLogDebug(frmt, ...)    do{ if(SG_LOG_LEVEL >= 4) NSLog((frmt), ##__VA_ARGS__); } while(0)
#define NSLogVerbose(frmt, ...)  do{ if(SG_LOG_LEVEL >= 5) NSLog((frmt), ##__VA_ARGS__); } while(0)

// Xcode does NOT natively support colors in the Xcode debugging console.
// You'll need to install the XcodeColors plugin to see colors in the Xcode console.
// https://github.com/robbiehanson/XcodeColors
//
// The following is documentation from the XcodeColors project:
//
//
// How to apply color formatting to your log statements:
//
// To set the foreground color:
// Insert the ESCAPE_SEQ into your string, followed by "fg124,12,255;" where r=124, g=12, b=255.
//
// To set the background color:
// Insert the ESCAPE_SEQ into your string, followed by "bg12,24,36;" where r=12, g=24, b=36.
//
// To reset the foreground color (to default value):
// Insert the ESCAPE_SEQ into your string, followed by "fg;"
//
// To reset the background color (to default value):
// Insert the ESCAPE_SEQ into your string, followed by "bg;"
//
// To reset the foreground and background color (to default values) in one operation:
// Insert the ESCAPE_SEQ into your string, followed by ";"

#define XCODE_COLORS_ESCAPE_SEQ "\033["

#define XCODE_COLORS_RESET_FG   XCODE_COLORS_ESCAPE_SEQ "fg;" // Clear any foreground color
#define XCODE_COLORS_RESET_BG   XCODE_COLORS_ESCAPE_SEQ "bg;" // Clear any background color
#define XCODE_COLORS_RESET      XCODE_COLORS_ESCAPE_SEQ ";"  // Clear any foreground or background color

// If running in a shell, not all RGB colors will be supported.
// In this case we automatically map to the closest available color.
// In order to provide this mapping, we have a hard-coded set of the standard RGB values available in the shell.
// However, not every shell is the same, and Apple likes to think different even when it comes to shell colors.
//
// Map to standard Terminal.app colors (1), or
// map to standard xterm colors (0).

#define MAP_TO_TERMINAL_APP_COLORS 1


@interface SGTTYLoggerColorProfile : NSObject {
    @public
    int mask;
    int context;

    uint8_t fg_r;
    uint8_t fg_g;
    uint8_t fg_b;

    uint8_t bg_r;
    uint8_t bg_g;
    uint8_t bg_b;

    NSUInteger fgCodeIndex;
    NSString *fgCodeRaw;

    NSUInteger bgCodeIndex;
    NSString *bgCodeRaw;

    char fgCode[24];
    size_t fgCodeLen;

    char bgCode[24];
    size_t bgCodeLen;

    char resetCode[8];
    size_t resetCodeLen;
}

- (instancetype)initWithForegroundColor:(SGColor *)fgColor backgroundColor:(SGColor *)bgColor flag:(int)mask context:(int)ctxt;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface SGTTYLogger () {
    NSUInteger _calendarUnitFlags;
    
    NSString *_appName;
    char *_app;
    size_t _appLen;
    
    NSString *_processID;
    char *_pid;
    size_t _pidLen;
    
    BOOL _colorsEnabled;
    NSMutableArray *_colorProfilesArray;
    NSMutableDictionary *_colorProfilesDict;
}

@end


@implementation SGTTYLogger

static BOOL isaColorTTY;
static BOOL isaColor256TTY;
static BOOL isaXcodeColorTTY;

static NSArray *codes_fg = nil;
static NSArray *codes_bg = nil;
static NSArray *colors   = nil;

static SGTTYLogger *sharedInstance;

/**
 * Initializes the colors array, as well as the codes_fg and codes_bg arrays, for 16 color mode.
 *
 * This method is used when the application is running from within a shell that only supports 16 color mode.
 * This method is not invoked if the application is running within Xcode, or via normal UI app launch.
 **/
+ (void)initialize_colors_16 {
    if (codes_fg || codes_bg || colors) {
        return;
    }

    NSMutableArray *m_codes_fg = [NSMutableArray arrayWithCapacity:16];
    NSMutableArray *m_codes_bg = [NSMutableArray arrayWithCapacity:16];
    NSMutableArray *m_colors   = [NSMutableArray arrayWithCapacity:16];

    // In a standard shell only 16 colors are supported.
    //
    // More information about ansi escape codes can be found online.
    // http://en.wikipedia.org/wiki/ANSI_escape_code

    [m_codes_fg addObject:@"30m"];   // normal - black
    [m_codes_fg addObject:@"31m"];   // normal - red
    [m_codes_fg addObject:@"32m"];   // normal - green
    [m_codes_fg addObject:@"33m"];   // normal - yellow
    [m_codes_fg addObject:@"34m"];   // normal - blue
    [m_codes_fg addObject:@"35m"];   // normal - magenta
    [m_codes_fg addObject:@"36m"];   // normal - cyan
    [m_codes_fg addObject:@"37m"];   // normal - gray
    [m_codes_fg addObject:@"1;30m"]; // bright - darkgray
    [m_codes_fg addObject:@"1;31m"]; // bright - red
    [m_codes_fg addObject:@"1;32m"]; // bright - green
    [m_codes_fg addObject:@"1;33m"]; // bright - yellow
    [m_codes_fg addObject:@"1;34m"]; // bright - blue
    [m_codes_fg addObject:@"1;35m"]; // bright - magenta
    [m_codes_fg addObject:@"1;36m"]; // bright - cyan
    [m_codes_fg addObject:@"1;37m"]; // bright - white

    [m_codes_bg addObject:@"40m"];   // normal - black
    [m_codes_bg addObject:@"41m"];   // normal - red
    [m_codes_bg addObject:@"42m"];   // normal - green
    [m_codes_bg addObject:@"43m"];   // normal - yellow
    [m_codes_bg addObject:@"44m"];   // normal - blue
    [m_codes_bg addObject:@"45m"];   // normal - magenta
    [m_codes_bg addObject:@"46m"];   // normal - cyan
    [m_codes_bg addObject:@"47m"];   // normal - gray
    [m_codes_bg addObject:@"1;40m"]; // bright - darkgray
    [m_codes_bg addObject:@"1;41m"]; // bright - red
    [m_codes_bg addObject:@"1;42m"]; // bright - green
    [m_codes_bg addObject:@"1;43m"]; // bright - yellow
    [m_codes_bg addObject:@"1;44m"]; // bright - blue
    [m_codes_bg addObject:@"1;45m"]; // bright - magenta
    [m_codes_bg addObject:@"1;46m"]; // bright - cyan
    [m_codes_bg addObject:@"1;47m"]; // bright - white

#if MAP_TO_TERMINAL_APP_COLORS

    // Standard Terminal.app colors:
    //
    // These are the default colors used by Apple's Terminal.app.

    [m_colors addObject:SGMakeColor(  0,   0,   0)]; // normal - black
    [m_colors addObject:SGMakeColor(194,  54,  33)]; // normal - red
    [m_colors addObject:SGMakeColor( 37, 188,  36)]; // normal - green
    [m_colors addObject:SGMakeColor(173, 173,  39)]; // normal - yellow
    [m_colors addObject:SGMakeColor( 73,  46, 225)]; // normal - blue
    [m_colors addObject:SGMakeColor(211,  56, 211)]; // normal - magenta
    [m_colors addObject:SGMakeColor( 51, 187, 200)]; // normal - cyan
    [m_colors addObject:SGMakeColor(203, 204, 205)]; // normal - gray
    [m_colors addObject:SGMakeColor(129, 131, 131)]; // bright - darkgray
    [m_colors addObject:SGMakeColor(252,  57,  31)]; // bright - red
    [m_colors addObject:SGMakeColor( 49, 231,  34)]; // bright - green
    [m_colors addObject:SGMakeColor(234, 236,  35)]; // bright - yellow
    [m_colors addObject:SGMakeColor( 88,  51, 255)]; // bright - blue
    [m_colors addObject:SGMakeColor(249,  53, 248)]; // bright - magenta
    [m_colors addObject:SGMakeColor( 20, 240, 240)]; // bright - cyan
    [m_colors addObject:SGMakeColor(233, 235, 235)]; // bright - white

#else /* if MAP_TO_TERMINAL_APP_COLORS */

    // Standard xterm colors:
    //
    // These are the default colors used by most xterm shells.

    [m_colors addObject:SGMakeColor(  0,   0,   0)]; // normal - black
    [m_colors addObject:SGMakeColor(205,   0,   0)]; // normal - red
    [m_colors addObject:SGMakeColor(  0, 205,   0)]; // normal - green
    [m_colors addObject:SGMakeColor(205, 205,   0)]; // normal - yellow
    [m_colors addObject:SGMakeColor(  0,   0, 238)]; // normal - blue
    [m_colors addObject:SGMakeColor(205,   0, 205)]; // normal - magenta
    [m_colors addObject:SGMakeColor(  0, 205, 205)]; // normal - cyan
    [m_colors addObject:SGMakeColor(229, 229, 229)]; // normal - gray
    [m_colors addObject:SGMakeColor(127, 127, 127)]; // bright - darkgray
    [m_colors addObject:SGMakeColor(255,   0,   0)]; // bright - red
    [m_colors addObject:SGMakeColor(  0, 255,   0)]; // bright - green
    [m_colors addObject:SGMakeColor(255, 255,   0)]; // bright - yellow
    [m_colors addObject:SGMakeColor( 92,  92, 255)]; // bright - blue
    [m_colors addObject:SGMakeColor(255,   0, 255)]; // bright - magenta
    [m_colors addObject:SGMakeColor(  0, 255, 255)]; // bright - cyan
    [m_colors addObject:SGMakeColor(255, 255, 255)]; // bright - white

#endif /* if MAP_TO_TERMINAL_APP_COLORS */

    codes_fg = [m_codes_fg copy];
    codes_bg = [m_codes_bg copy];
    colors   = [m_colors   copy];

    NSAssert([codes_fg count] == [codes_bg count], @"Invalid colors/codes array(s)");
    NSAssert([codes_fg count] == [colors count],   @"Invalid colors/codes array(s)");
}

/**
 * Initializes the colors array, as well as the codes_fg and codes_bg arrays, for 256 color mode.
 *
 * This method is used when the application is running from within a shell that supports 256 color mode.
 * This method is not invoked if the application is running within Xcode, or via normal UI app launch.
 **/
+ (void)initialize_colors_256 {
    if (codes_fg || codes_bg || colors) {
        return;
    }

    NSMutableArray *m_codes_fg = [NSMutableArray arrayWithCapacity:(256 - 16)];
    NSMutableArray *m_codes_bg = [NSMutableArray arrayWithCapacity:(256 - 16)];
    NSMutableArray *m_colors   = [NSMutableArray arrayWithCapacity:(256 - 16)];

    #if MAP_TO_TERMINAL_APP_COLORS

    // Standard Terminal.app colors:
    //
    // These are the colors the Terminal.app uses in xterm-256color mode.
    // In this mode, the terminal supports 256 different colors, specified by 256 color codes.
    //
    // The first 16 color codes map to the original 16 color codes supported by the earlier xterm-color mode.
    // These are actually configurable, and thus we ignore them for the purposes of mapping,
    // as we can't rely on them being constant. They are largely duplicated anyway.
    //
    // The next 216 color codes are designed to run the spectrum, with several shades of every color.
    // While the color codes are standardized, the actual RGB values for each color code is not.
    // Apple's Terminal.app uses different RGB values from that of a standard xterm.
    // Apple's choices in colors are designed to be a little nicer on the eyes.
    //
    // The last 24 color codes represent a grayscale.
    //
    // Unfortunately, unlike the standard xterm color chart,
    // Apple's RGB values cannot be calculated using a simple formula (at least not that I know of).
    // Also, I don't know of any ways to programmatically query the shell for the RGB values.
    // So this big giant color chart had to be made by hand.
    //
    // More information about ansi escape codes can be found online.
    // http://en.wikipedia.org/wiki/ANSI_escape_code

    // Colors

    [m_colors addObject:SGMakeColor( 47,  49,  49)];
    [m_colors addObject:SGMakeColor( 60,  42, 144)];
    [m_colors addObject:SGMakeColor( 66,  44, 183)];
    [m_colors addObject:SGMakeColor( 73,  46, 222)];
    [m_colors addObject:SGMakeColor( 81,  50, 253)];
    [m_colors addObject:SGMakeColor( 88,  51, 255)];
    
    [m_colors addObject:SGMakeColor( 42, 128,  37)];
    [m_colors addObject:SGMakeColor( 42, 127, 128)];
    [m_colors addObject:SGMakeColor( 44, 126, 169)];
    [m_colors addObject:SGMakeColor( 56, 125, 209)];
    [m_colors addObject:SGMakeColor( 59, 124, 245)];
    [m_colors addObject:SGMakeColor( 66, 123, 255)];
    
    [m_colors addObject:SGMakeColor( 51, 163,  41)];
    [m_colors addObject:SGMakeColor( 39, 162, 121)];
    [m_colors addObject:SGMakeColor( 42, 161, 162)];
    [m_colors addObject:SGMakeColor( 53, 160, 202)];
    [m_colors addObject:SGMakeColor( 45, 159, 240)];
    [m_colors addObject:SGMakeColor( 58, 158, 255)];
    
    [m_colors addObject:SGMakeColor( 31, 196,  37)];
    [m_colors addObject:SGMakeColor( 48, 196, 115)];
    [m_colors addObject:SGMakeColor( 39, 195, 155)];
    [m_colors addObject:SGMakeColor( 49, 195, 195)];
    [m_colors addObject:SGMakeColor( 32, 194, 235)];
    [m_colors addObject:SGMakeColor( 53, 193, 255)];
    
    [m_colors addObject:SGMakeColor( 50, 229,  35)];
    [m_colors addObject:SGMakeColor( 40, 229, 109)];
    [m_colors addObject:SGMakeColor( 27, 229, 149)];
    [m_colors addObject:SGMakeColor( 49, 228, 189)];
    [m_colors addObject:SGMakeColor( 33, 228, 228)];
    [m_colors addObject:SGMakeColor( 53, 227, 255)];
    
    [m_colors addObject:SGMakeColor( 27, 254,  30)];
    [m_colors addObject:SGMakeColor( 30, 254, 103)];
    [m_colors addObject:SGMakeColor( 45, 254, 143)];
    [m_colors addObject:SGMakeColor( 38, 253, 182)];
    [m_colors addObject:SGMakeColor( 38, 253, 222)];
    [m_colors addObject:SGMakeColor( 42, 253, 252)];
    
    [m_colors addObject:SGMakeColor(140,  48,  40)];
    [m_colors addObject:SGMakeColor(136,  51, 136)];
    [m_colors addObject:SGMakeColor(135,  52, 177)];
    [m_colors addObject:SGMakeColor(134,  52, 217)];
    [m_colors addObject:SGMakeColor(135,  56, 248)];
    [m_colors addObject:SGMakeColor(134,  53, 255)];
    
    [m_colors addObject:SGMakeColor(125, 125,  38)];
    [m_colors addObject:SGMakeColor(124, 125, 125)];
    [m_colors addObject:SGMakeColor(122, 124, 166)];
    [m_colors addObject:SGMakeColor(123, 124, 207)];
    [m_colors addObject:SGMakeColor(123, 122, 247)];
    [m_colors addObject:SGMakeColor(124, 121, 255)];
    
    [m_colors addObject:SGMakeColor(119, 160,  35)];
    [m_colors addObject:SGMakeColor(117, 160, 120)];
    [m_colors addObject:SGMakeColor(117, 160, 160)];
    [m_colors addObject:SGMakeColor(115, 159, 201)];
    [m_colors addObject:SGMakeColor(116, 158, 240)];
    [m_colors addObject:SGMakeColor(117, 157, 255)];
    
    [m_colors addObject:SGMakeColor(113, 195,  39)];
    [m_colors addObject:SGMakeColor(110, 194, 114)];
    [m_colors addObject:SGMakeColor(111, 194, 154)];
    [m_colors addObject:SGMakeColor(108, 194, 194)];
    [m_colors addObject:SGMakeColor(109, 193, 234)];
    [m_colors addObject:SGMakeColor(108, 192, 255)];
    
    [m_colors addObject:SGMakeColor(105, 228,  30)];
    [m_colors addObject:SGMakeColor(103, 228, 109)];
    [m_colors addObject:SGMakeColor(105, 228, 148)];
    [m_colors addObject:SGMakeColor(100, 227, 188)];
    [m_colors addObject:SGMakeColor( 99, 227, 227)];
    [m_colors addObject:SGMakeColor( 99, 226, 253)];
    
    [m_colors addObject:SGMakeColor( 92, 253,  34)];
    [m_colors addObject:SGMakeColor( 96, 253, 103)];
    [m_colors addObject:SGMakeColor( 97, 253, 142)];
    [m_colors addObject:SGMakeColor( 88, 253, 182)];
    [m_colors addObject:SGMakeColor( 93, 253, 221)];
    [m_colors addObject:SGMakeColor( 88, 254, 251)];
    
    [m_colors addObject:SGMakeColor(177,  53,  34)];
    [m_colors addObject:SGMakeColor(174,  54, 131)];
    [m_colors addObject:SGMakeColor(172,  55, 172)];
    [m_colors addObject:SGMakeColor(171,  57, 213)];
    [m_colors addObject:SGMakeColor(170,  55, 249)];
    [m_colors addObject:SGMakeColor(170,  57, 255)];
    
    [m_colors addObject:SGMakeColor(165, 123,  37)];
    [m_colors addObject:SGMakeColor(163, 123, 123)];
    [m_colors addObject:SGMakeColor(162, 123, 164)];
    [m_colors addObject:SGMakeColor(161, 122, 205)];
    [m_colors addObject:SGMakeColor(161, 121, 241)];
    [m_colors addObject:SGMakeColor(161, 121, 255)];
    
    [m_colors addObject:SGMakeColor(158, 159,  33)];
    [m_colors addObject:SGMakeColor(157, 158, 118)];
    [m_colors addObject:SGMakeColor(157, 158, 159)];
    [m_colors addObject:SGMakeColor(155, 157, 199)];
    [m_colors addObject:SGMakeColor(155, 157, 239)];
    [m_colors addObject:SGMakeColor(154, 156, 255)];
    
    [m_colors addObject:SGMakeColor(152, 193,  40)];
    [m_colors addObject:SGMakeColor(151, 193, 113)];
    [m_colors addObject:SGMakeColor(150, 193, 153)];
    [m_colors addObject:SGMakeColor(150, 192, 193)];
    [m_colors addObject:SGMakeColor(148, 192, 232)];
    [m_colors addObject:SGMakeColor(149, 191, 253)];
    
    [m_colors addObject:SGMakeColor(146, 227,  28)];
    [m_colors addObject:SGMakeColor(144, 227, 108)];
    [m_colors addObject:SGMakeColor(144, 227, 147)];
    [m_colors addObject:SGMakeColor(144, 227, 187)];
    [m_colors addObject:SGMakeColor(142, 226, 227)];
    [m_colors addObject:SGMakeColor(142, 225, 252)];
    
    [m_colors addObject:SGMakeColor(138, 253,  36)];
    [m_colors addObject:SGMakeColor(137, 253, 102)];
    [m_colors addObject:SGMakeColor(136, 253, 141)];
    [m_colors addObject:SGMakeColor(138, 254, 181)];
    [m_colors addObject:SGMakeColor(135, 255, 220)];
    [m_colors addObject:SGMakeColor(133, 255, 250)];
    
    [m_colors addObject:SGMakeColor(214,  57,  30)];
    [m_colors addObject:SGMakeColor(211,  59, 126)];
    [m_colors addObject:SGMakeColor(209,  57, 168)];
    [m_colors addObject:SGMakeColor(208,  55, 208)];
    [m_colors addObject:SGMakeColor(207,  58, 247)];
    [m_colors addObject:SGMakeColor(206,  61, 255)];
    
    [m_colors addObject:SGMakeColor(204, 121,  32)];
    [m_colors addObject:SGMakeColor(202, 121, 121)];
    [m_colors addObject:SGMakeColor(201, 121, 161)];
    [m_colors addObject:SGMakeColor(200, 120, 202)];
    [m_colors addObject:SGMakeColor(200, 120, 241)];
    [m_colors addObject:SGMakeColor(198, 119, 255)];
    
    [m_colors addObject:SGMakeColor(198, 157,  37)];
    [m_colors addObject:SGMakeColor(196, 157, 116)];
    [m_colors addObject:SGMakeColor(195, 156, 157)];
    [m_colors addObject:SGMakeColor(195, 156, 197)];
    [m_colors addObject:SGMakeColor(194, 155, 236)];
    [m_colors addObject:SGMakeColor(193, 155, 255)];
    
    [m_colors addObject:SGMakeColor(191, 192,  36)];
    [m_colors addObject:SGMakeColor(190, 191, 112)];
    [m_colors addObject:SGMakeColor(189, 191, 152)];
    [m_colors addObject:SGMakeColor(189, 191, 191)];
    [m_colors addObject:SGMakeColor(188, 190, 230)];
    [m_colors addObject:SGMakeColor(187, 190, 253)];
    
    [m_colors addObject:SGMakeColor(185, 226,  28)];
    [m_colors addObject:SGMakeColor(184, 226, 106)];
    [m_colors addObject:SGMakeColor(183, 225, 146)];
    [m_colors addObject:SGMakeColor(183, 225, 186)];
    [m_colors addObject:SGMakeColor(182, 225, 225)];
    [m_colors addObject:SGMakeColor(181, 224, 252)];
    
    [m_colors addObject:SGMakeColor(178, 255,  35)];
    [m_colors addObject:SGMakeColor(178, 255, 101)];
    [m_colors addObject:SGMakeColor(177, 254, 141)];
    [m_colors addObject:SGMakeColor(176, 254, 180)];
    [m_colors addObject:SGMakeColor(176, 254, 220)];
    [m_colors addObject:SGMakeColor(175, 253, 249)];
    
    [m_colors addObject:SGMakeColor(247,  56,  30)];
    [m_colors addObject:SGMakeColor(245,  57, 122)];
    [m_colors addObject:SGMakeColor(243,  59, 163)];
    [m_colors addObject:SGMakeColor(244,  60, 204)];
    [m_colors addObject:SGMakeColor(242,  59, 241)];
    [m_colors addObject:SGMakeColor(240,  55, 255)];
    
    [m_colors addObject:SGMakeColor(241, 119,  36)];
    [m_colors addObject:SGMakeColor(240, 120, 118)];
    [m_colors addObject:SGMakeColor(238, 119, 158)];
    [m_colors addObject:SGMakeColor(237, 119, 199)];
    [m_colors addObject:SGMakeColor(237, 118, 238)];
    [m_colors addObject:SGMakeColor(236, 118, 255)];
    
    [m_colors addObject:SGMakeColor(235, 154,  36)];
    [m_colors addObject:SGMakeColor(235, 154, 114)];
    [m_colors addObject:SGMakeColor(234, 154, 154)];
    [m_colors addObject:SGMakeColor(232, 154, 194)];
    [m_colors addObject:SGMakeColor(232, 153, 234)];
    [m_colors addObject:SGMakeColor(232, 153, 255)];
    
    [m_colors addObject:SGMakeColor(230, 190,  30)];
    [m_colors addObject:SGMakeColor(229, 189, 110)];
    [m_colors addObject:SGMakeColor(228, 189, 150)];
    [m_colors addObject:SGMakeColor(227, 189, 190)];
    [m_colors addObject:SGMakeColor(227, 189, 229)];
    [m_colors addObject:SGMakeColor(226, 188, 255)];
    
    [m_colors addObject:SGMakeColor(224, 224,  35)];
    [m_colors addObject:SGMakeColor(223, 224, 105)];
    [m_colors addObject:SGMakeColor(222, 224, 144)];
    [m_colors addObject:SGMakeColor(222, 223, 184)];
    [m_colors addObject:SGMakeColor(222, 223, 224)];
    [m_colors addObject:SGMakeColor(220, 223, 253)];
    
    [m_colors addObject:SGMakeColor(217, 253,  28)];
    [m_colors addObject:SGMakeColor(217, 253,  99)];
    [m_colors addObject:SGMakeColor(216, 252, 139)];
    [m_colors addObject:SGMakeColor(216, 252, 179)];
    [m_colors addObject:SGMakeColor(215, 252, 218)];
    [m_colors addObject:SGMakeColor(215, 251, 250)];
    
    [m_colors addObject:SGMakeColor(255,  61,  30)];
    [m_colors addObject:SGMakeColor(255,  60, 118)];
    [m_colors addObject:SGMakeColor(255,  58, 159)];
    [m_colors addObject:SGMakeColor(255,  56, 199)];
    [m_colors addObject:SGMakeColor(255,  55, 238)];
    [m_colors addObject:SGMakeColor(255,  59, 255)];
    
    [m_colors addObject:SGMakeColor(255, 117,  29)];
    [m_colors addObject:SGMakeColor(255, 117, 115)];
    [m_colors addObject:SGMakeColor(255, 117, 155)];
    [m_colors addObject:SGMakeColor(255, 117, 195)];
    [m_colors addObject:SGMakeColor(255, 116, 235)];
    [m_colors addObject:SGMakeColor(254, 116, 255)];
    
    [m_colors addObject:SGMakeColor(255, 152,  27)];
    [m_colors addObject:SGMakeColor(255, 152, 111)];
    [m_colors addObject:SGMakeColor(254, 152, 152)];
    [m_colors addObject:SGMakeColor(255, 152, 192)];
    [m_colors addObject:SGMakeColor(254, 151, 231)];
    [m_colors addObject:SGMakeColor(253, 151, 253)];
    
    [m_colors addObject:SGMakeColor(255, 187,  33)];
    [m_colors addObject:SGMakeColor(253, 187, 107)];
    [m_colors addObject:SGMakeColor(252, 187, 148)];
    [m_colors addObject:SGMakeColor(253, 187, 187)];
    [m_colors addObject:SGMakeColor(254, 187, 227)];
    [m_colors addObject:SGMakeColor(252, 186, 252)];
    
    [m_colors addObject:SGMakeColor(252, 222,  34)];
    [m_colors addObject:SGMakeColor(251, 222, 103)];
    [m_colors addObject:SGMakeColor(251, 222, 143)];
    [m_colors addObject:SGMakeColor(250, 222, 182)];
    [m_colors addObject:SGMakeColor(251, 221, 222)];
    [m_colors addObject:SGMakeColor(252, 221, 252)];
    
    [m_colors addObject:SGMakeColor(251, 252,  15)];
    [m_colors addObject:SGMakeColor(251, 252,  97)];
    [m_colors addObject:SGMakeColor(249, 252, 137)];
    [m_colors addObject:SGMakeColor(247, 252, 177)];
    [m_colors addObject:SGMakeColor(247, 253, 217)];
    [m_colors addObject:SGMakeColor(254, 255, 255)];
    
    // Grayscale
    
    [m_colors addObject:SGMakeColor( 52,  53,  53)];
    [m_colors addObject:SGMakeColor( 57,  58,  59)];
    [m_colors addObject:SGMakeColor( 66,  67,  67)];
    [m_colors addObject:SGMakeColor( 75,  76,  76)];
    [m_colors addObject:SGMakeColor( 83,  85,  85)];
    [m_colors addObject:SGMakeColor( 92,  93,  94)];
    
    [m_colors addObject:SGMakeColor(101, 102, 102)];
    [m_colors addObject:SGMakeColor(109, 111, 111)];
    [m_colors addObject:SGMakeColor(118, 119, 119)];
    [m_colors addObject:SGMakeColor(126, 127, 128)];
    [m_colors addObject:SGMakeColor(134, 136, 136)];
    [m_colors addObject:SGMakeColor(143, 144, 145)];
    
    [m_colors addObject:SGMakeColor(151, 152, 153)];
    [m_colors addObject:SGMakeColor(159, 161, 161)];
    [m_colors addObject:SGMakeColor(167, 169, 169)];
    [m_colors addObject:SGMakeColor(176, 177, 177)];
    [m_colors addObject:SGMakeColor(184, 185, 186)];
    [m_colors addObject:SGMakeColor(192, 193, 194)];
    
    [m_colors addObject:SGMakeColor(200, 201, 202)];
    [m_colors addObject:SGMakeColor(208, 209, 210)];
    [m_colors addObject:SGMakeColor(216, 218, 218)];
    [m_colors addObject:SGMakeColor(224, 226, 226)];
    [m_colors addObject:SGMakeColor(232, 234, 234)];
    [m_colors addObject:SGMakeColor(240, 242, 242)];
    
    // Color codes

    int index = 16;

    while (index < 256) {
        [m_codes_fg addObject:[NSString stringWithFormat:@"38;5;%dm", index]];
        [m_codes_bg addObject:[NSString stringWithFormat:@"48;5;%dm", index]];

        index++;
    }

    #else /* if MAP_TO_TERMINAL_APP_COLORS */

    // Standard xterm colors:
    //
    // These are the colors xterm shells use in xterm-256color mode.
    // In this mode, the shell supports 256 different colors, specified by 256 color codes.
    //
    // The first 16 color codes map to the original 16 color codes supported by the earlier xterm-color mode.
    // These are generally configurable, and thus we ignore them for the purposes of mapping,
    // as we can't rely on them being constant. They are largely duplicated anyway.
    //
    // The next 216 color codes are designed to run the spectrum, with several shades of every color.
    // The last 24 color codes represent a grayscale.
    //
    // While the color codes are standardized, the actual RGB values for each color code is not.
    // However most standard xterms follow a well known color chart,
    // which can easily be calculated using the simple formula below.
    //
    // More information about ansi escape codes can be found online.
    // http://en.wikipedia.org/wiki/ANSI_escape_code

    int index = 16;

    int r; // red
    int g; // green
    int b; // blue

    int ri; // r increment
    int gi; // g increment
    int bi; // b increment

    // Calculate xterm colors (using standard algorithm)

    int r = 0;
    int g = 0;
    int b = 0;

    for (ri = 0; ri < 6; ri++) {
        r = (ri == 0) ? 0 : 95 + (40 * (ri - 1));

        for (gi = 0; gi < 6; gi++) {
            g = (gi == 0) ? 0 : 95 + (40 * (gi - 1));

            for (bi = 0; bi < 6; bi++) {
                b = (bi == 0) ? 0 : 95 + (40 * (bi - 1));

                [m_codes_fg addObject:[NSString stringWithFormat:@"38;5;%dm", index]];
                [m_codes_bg addObject:[NSString stringWithFormat:@"48;5;%dm", index]];
                [m_colors addObject:SGMakeColor(r, g, b)];

                index++;
            }
        }
    }

    // Calculate xterm grayscale (using standard algorithm)

    r = 8;
    g = 8;
    b = 8;

    while (index < 256) {
        [m_codes_fg addObject:[NSString stringWithFormat:@"38;5;%dm", index]];
        [m_codes_bg addObject:[NSString stringWithFormat:@"48;5;%dm", index]];
        [m_colors addObject:SGMakeColor(r, g, b)];

        r += 10;
        g += 10;
        b += 10;

        index++;
    }

    #endif /* if MAP_TO_TERMINAL_APP_COLORS */

    codes_fg = [m_codes_fg copy];
    codes_bg = [m_codes_bg copy];
    colors   = [m_colors   copy];

    NSAssert([codes_fg count] == [codes_bg count], @"Invalid colors/codes array(s)");
    NSAssert([codes_fg count] == [colors count],   @"Invalid colors/codes array(s)");
}

+ (void)getRed:(CGFloat *)rPtr green:(CGFloat *)gPtr blue:(CGFloat *)bPtr fromColor:(SGColor *)color {
    #if TARGET_OS_IPHONE

    // iOS

    BOOL done = NO;

    if ([color respondsToSelector:@selector(getRed:green:blue:alpha:)]) {
        done = [color getRed:rPtr green:gPtr blue:bPtr alpha:NULL];
    }

    if (!done) {
        // The method getRed:green:blue:alpha: was only available starting iOS 5.
        // So in iOS 4 and earlier, we have to jump through hoops.

        CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();

        unsigned char pixel[4];
        CGContextRef context = CGBitmapContextCreate(&pixel, 1, 1, 8, 4, rgbColorSpace, kCGBitmapAlphaInfoMask & kCGImageAlphaNoneSkipLast);

        CGContextSetFillColorWithColor(context, [color CGColor]);
        CGContextFillRect(context, CGRectMake(0, 0, 1, 1));

        if (rPtr) {
            *rPtr = pixel[0] / 255.0f;
        }

        if (gPtr) {
            *gPtr = pixel[1] / 255.0f;
        }

        if (bPtr) {
            *bPtr = pixel[2] / 255.0f;
        }

        CGContextRelease(context);
        CGColorSpaceRelease(rgbColorSpace);
    }

    #elif __has_include(<AppKit/NSColor.h>)

    // OS X with AppKit

    NSColor *safeColor = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];

    [safeColor getRed:rPtr green:gPtr blue:bPtr alpha:NULL];

    #else /* if TARGET_OS_IPHONE */

    // OS X without AppKit

    [color getRed:rPtr green:gPtr blue:bPtr alpha:NULL];

    #endif /* if TARGET_OS_IPHONE */
}

/**
 * Maps the given color to the closest available color supported by the shell.
 * The shell may support 256 colors, or only 16.
 *
 * This method loops through the known supported color set, and calculates the closest color.
 * The array index of that color, within the colors array, is then returned.
 * This array index may also be used as the index within the codes_fg and codes_bg arrays.
 **/
+ (NSUInteger)codeIndexForColor:(SGColor *)inColor {
    CGFloat inR, inG, inB;

    [self getRed:&inR green:&inG blue:&inB fromColor:inColor];

    NSUInteger bestIndex = 0;
    CGFloat lowestDistance = 100.0f;

    NSUInteger i = 0;

    for (SGColor *color in colors) {
        // Calculate Euclidean distance (lower value means closer to given color)

        CGFloat r, g, b;
        [self getRed:&r green:&g blue:&b fromColor:color];

    #if CGFLOAT_IS_DOUBLE
        CGFloat distance = sqrt(pow(r - inR, 2.0) + pow(g - inG, 2.0) + pow(b - inB, 2.0));
    #else
        CGFloat distance = sqrtf(powf(r - inR, 2.0f) + powf(g - inG, 2.0f) + powf(b - inB, 2.0f));
    #endif

        NSLogVerbose(@"SGTTYLogger: %3lu : %.3f,%.3f,%.3f & %.3f,%.3f,%.3f = %.6f",
                     (unsigned long)i, inR, inG, inB, r, g, b, distance);

        if (distance < lowestDistance) {
            bestIndex = i;
            lowestDistance = distance;

            NSLogVerbose(@"SGTTYLogger: New best index = %lu", (unsigned long)bestIndex);
        }

        i++;
    }

    return bestIndex;
}

+ (instancetype)sharedInstance {
    static dispatch_once_t SGTTYLoggerOnceToken;

    dispatch_once(&SGTTYLoggerOnceToken, ^{
        // Xcode does NOT natively support colors in the Xcode debugging console.
        // You'll need to install the XcodeColors plugin to see colors in the Xcode console.
        //
        // PS - Please read the header file before diving into the source code.

        char *xcode_colors = getenv("XcodeColors");
        char *term = getenv("TERM");

        if (xcode_colors && (strcmp(xcode_colors, "YES") == 0)) {
            isaXcodeColorTTY = YES;
        } else if (term) {
            if (strcasestr(term, "color") != NULL) {
                isaColorTTY = YES;
                isaColor256TTY = (strcasestr(term, "256") != NULL);

                if (isaColor256TTY) {
                    [self initialize_colors_256];
                } else {
                    [self initialize_colors_16];
                }
            }
        }

        NSLogInfo(@"SGTTYLogger: isaColorTTY = %@", (isaColorTTY ? @"YES" : @"NO"));
        NSLogInfo(@"SGTTYLogger: isaColor256TTY: %@", (isaColor256TTY ? @"YES" : @"NO"));
        NSLogInfo(@"SGTTYLogger: isaXcodeColorTTY: %@", (isaXcodeColorTTY ? @"YES" : @"NO"));

        sharedInstance = [[[self class] alloc] init];
    });

    return sharedInstance;
}

- (id)init {
    if (sharedInstance != nil) {
        return nil;
    }

    if ((self = [super init])) {
        _calendarUnitFlags = (NSCalendarUnitYear     |
                             NSCalendarUnitMonth    |
                             NSCalendarUnitDay      |
                             NSCalendarUnitHour     |
                             NSCalendarUnitMinute   |
                             NSCalendarUnitSecond);

        // Initialze 'app' variable (char *)

        _appName = [[NSProcessInfo processInfo] processName];

        _appLen = [_appName lengthOfBytesUsingEncoding:NSUTF8StringEncoding];

        if (_appLen == 0) {
            _appName = @"<UnnamedApp>";
            _appLen = [_appName lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        }

        _app = (char *)malloc(_appLen + 1);

        if (_app == NULL) {
            return nil;
        }

        BOOL processedAppName = [_appName getCString:_app maxLength:(_appLen + 1) encoding:NSUTF8StringEncoding];

        if (NO == processedAppName) {
            return nil;
        }

        // Initialize 'pid' variable (char *)

        _processID = [NSString stringWithFormat:@"%i", (int)getpid()];

        _pidLen = [_processID lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        _pid = (char *)malloc(_pidLen + 1);

        if (_pid == NULL) {
            return nil;
        }

        BOOL processedID = [_processID getCString:_pid maxLength:(_pidLen + 1) encoding:NSUTF8StringEncoding];

        if (NO == processedID) {
            return nil;
        }

        // Initialize color stuff

        _colorsEnabled = NO;
        _colorProfilesArray = [[NSMutableArray alloc] initWithCapacity:8];
        _colorProfilesDict = [[NSMutableDictionary alloc] initWithCapacity:8];

        _automaticallyAppendNewlineForCustomFormatters = YES;
    }

    return self;
}

- (void)loadDefaultColorProfiles {
    [self setForegroundColor:SGMakeColor(214,  57,  30) backgroundColor:nil forFlag:SGLogFlagError];
    [self setForegroundColor:SGMakeColor(204, 121,  32) backgroundColor:nil forFlag:SGLogFlagWarning];
}

- (BOOL)colorsEnabled {
    // The design of this method is taken from the SGAbstractLogger implementation.
    // For extensive documentation please refer to the SGAbstractLogger implementation.

    // Note: The internal implementation MUST access the colorsEnabled variable directly,
    // This method is designed explicitly for external access.
    //
    // Using "self." syntax to go through this method will cause immediate deadlock.
    // This is the intended result. Fix it by accessing the ivar directly.
    // Great strides have been take to ensure this is safe to do. Plus it's MUCH faster.

    NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
    NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");

    dispatch_queue_t globalLoggingQueue = [SGLog loggingQueue];

    __block BOOL result;

    dispatch_sync(globalLoggingQueue, ^{
        dispatch_sync(loggerQueue, ^{
            result = _colorsEnabled;
        });
    });

    return result;
}

- (void)setColorsEnabled:(BOOL)newColorsEnabled {
    dispatch_block_t block = ^{
        @autoreleasepool {
            _colorsEnabled = newColorsEnabled;

            if ([_colorProfilesArray count] == 0) {
                [self loadDefaultColorProfiles];
            }
        }
    };

    // The design of this method is taken from the SGAbstractLogger implementation.
    // For extensive documentation please refer to the SGAbstractLogger implementation.

    // Note: The internal implementation MUST access the colorsEnabled variable directly,
    // This method is designed explicitly for external access.
    //
    // Using "self." syntax to go through this method will cause immediate deadlock.
    // This is the intended result. Fix it by accessing the ivar directly.
    // Great strides have been take to ensure this is safe to do. Plus it's MUCH faster.

    NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
    NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");

    dispatch_queue_t globalLoggingQueue = [SGLog loggingQueue];

    dispatch_async(globalLoggingQueue, ^{
        dispatch_async(loggerQueue, block);
    });
}

- (void)setForegroundColor:(SGColor *)txtColor backgroundColor:(SGColor *)bgColor forFlag:(int)mask {
    [self setForegroundColor:txtColor backgroundColor:bgColor forFlag:mask context:SG_LOG_CONTEXT_ALL];
}

- (void)setForegroundColor:(SGColor *)txtColor backgroundColor:(SGColor *)bgColor forFlag:(int)mask context:(int)ctxt {
    dispatch_block_t block = ^{
        @autoreleasepool {
            SGTTYLoggerColorProfile *newColorProfile =
                [[SGTTYLoggerColorProfile alloc] initWithForegroundColor:txtColor
                                                         backgroundColor:bgColor
                                                                    flag:mask
                                                                 context:ctxt];

            NSLogInfo(@"SGTTYLogger: newColorProfile: %@", newColorProfile);

            NSUInteger i = 0;

            for (SGTTYLoggerColorProfile *colorProfile in _colorProfilesArray) {
                if ((colorProfile->mask == mask) && (colorProfile->context == ctxt)) {
                    break;
                }

                i++;
            }

            if (i < [_colorProfilesArray count]) {
                [_colorProfilesArray replaceObjectAtIndex:i withObject:newColorProfile];
            } else {
                [_colorProfilesArray addObject:newColorProfile];
            }
        }
    };

    // The design of the setter logic below is taken from the SGAbstractLogger implementation.
    // For documentation please refer to the SGAbstractLogger implementation.

    if ([self isOnInternalLoggerQueue]) {
        block();
    } else {
        dispatch_queue_t globalLoggingQueue = [SGLog loggingQueue];
        NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");

        dispatch_async(globalLoggingQueue, ^{
            dispatch_async(loggerQueue, block);
        });
    }
}

- (void)setForegroundColor:(SGColor *)txtColor backgroundColor:(SGColor *)bgColor forTag:(id <NSCopying>)tag {
    NSAssert([(id < NSObject >) tag conformsToProtocol: @protocol(NSCopying)], @"Invalid tag");

    dispatch_block_t block = ^{
        @autoreleasepool {
            SGTTYLoggerColorProfile *newColorProfile =
                [[SGTTYLoggerColorProfile alloc] initWithForegroundColor:txtColor
                                                         backgroundColor:bgColor
                                                                    flag:0
                                                                 context:0];

            NSLogInfo(@"SGTTYLogger: newColorProfile: %@", newColorProfile);

            [_colorProfilesDict setObject:newColorProfile forKey:tag];
        }
    };

    // The design of the setter logic below is taken from the SGAbstractLogger implementation.
    // For documentation please refer to the SGAbstractLogger implementation.

    if ([self isOnInternalLoggerQueue]) {
        block();
    } else {
        dispatch_queue_t globalLoggingQueue = [SGLog loggingQueue];
        NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");

        dispatch_async(globalLoggingQueue, ^{
            dispatch_async(loggerQueue, block);
        });
    }
}

- (void)clearColorsForFlag:(int)mask {
    [self clearColorsForFlag:mask context:0];
}

- (void)clearColorsForFlag:(int)mask context:(int)context {
    dispatch_block_t block = ^{
        @autoreleasepool {
            NSUInteger i = 0;

            for (SGTTYLoggerColorProfile *colorProfile in _colorProfilesArray) {
                if ((colorProfile->mask == mask) && (colorProfile->context == context)) {
                    break;
                }

                i++;
            }

            if (i < [_colorProfilesArray count]) {
                [_colorProfilesArray removeObjectAtIndex:i];
            }
        }
    };

    // The design of the setter logic below is taken from the SGAbstractLogger implementation.
    // For documentation please refer to the SGAbstractLogger implementation.

    if ([self isOnInternalLoggerQueue]) {
        block();
    } else {
        dispatch_queue_t globalLoggingQueue = [SGLog loggingQueue];
        NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");

        dispatch_async(globalLoggingQueue, ^{
            dispatch_async(loggerQueue, block);
        });
    }
}

- (void)clearColorsForTag:(id <NSCopying>)tag {
    NSAssert([(id < NSObject >) tag conformsToProtocol: @protocol(NSCopying)], @"Invalid tag");

    dispatch_block_t block = ^{
        @autoreleasepool {
            [_colorProfilesDict removeObjectForKey:tag];
        }
    };

    // The design of the setter logic below is taken from the SGAbstractLogger implementation.
    // For documentation please refer to the SGAbstractLogger implementation.

    if ([self isOnInternalLoggerQueue]) {
        block();
    } else {
        dispatch_queue_t globalLoggingQueue = [SGLog loggingQueue];
        NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");

        dispatch_async(globalLoggingQueue, ^{
            dispatch_async(loggerQueue, block);
        });
    }
}

- (void)clearColorsForAllFlags {
    dispatch_block_t block = ^{
        @autoreleasepool {
            [_colorProfilesArray removeAllObjects];
        }
    };

    // The design of the setter logic below is taken from the SGAbstractLogger implementation.
    // For documentation please refer to the SGAbstractLogger implementation.

    if ([self isOnInternalLoggerQueue]) {
        block();
    } else {
        dispatch_queue_t globalLoggingQueue = [SGLog loggingQueue];
        NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");

        dispatch_async(globalLoggingQueue, ^{
            dispatch_async(loggerQueue, block);
        });
    }
}

- (void)clearColorsForAllTags {
    dispatch_block_t block = ^{
        @autoreleasepool {
            [_colorProfilesDict removeAllObjects];
        }
    };

    // The design of the setter logic below is taken from the SGAbstractLogger implementation.
    // For documentation please refer to the SGAbstractLogger implementation.

    if ([self isOnInternalLoggerQueue]) {
        block();
    } else {
        dispatch_queue_t globalLoggingQueue = [SGLog loggingQueue];
        NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");

        dispatch_async(globalLoggingQueue, ^{
            dispatch_async(loggerQueue, block);
        });
    }
}

- (void)clearAllColors {
    dispatch_block_t block = ^{
        @autoreleasepool {
            [_colorProfilesArray removeAllObjects];
            [_colorProfilesDict removeAllObjects];
        }
    };

    // The design of the setter logic below is taken from the SGAbstractLogger implementation.
    // For documentation please refer to the SGAbstractLogger implementation.

    if ([self isOnInternalLoggerQueue]) {
        block();
    } else {
        dispatch_queue_t globalLoggingQueue = [SGLog loggingQueue];
        NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");

        dispatch_async(globalLoggingQueue, ^{
            dispatch_async(loggerQueue, block);
        });
    }
}

- (void)logMessage:(SGLogMessage *)logMessage {
    NSString *logMsg = logMessage->logMsg;
    BOOL isFormatted = NO;

    if (formatter) {
        logMsg = [formatter formatLogMessage:logMessage];
        isFormatted = logMsg != logMessage->logMsg;
    }

    if (logMsg) {
        // Search for a color profile associated with the log message

        SGTTYLoggerColorProfile *colorProfile = nil;

        if (_colorsEnabled) {
            if (logMessage->tag) {
                colorProfile = [_colorProfilesDict objectForKey:logMessage->tag];
            }

            if (colorProfile == nil) {
                for (SGTTYLoggerColorProfile *cp in _colorProfilesArray) {
                    if (logMessage->logFlag & cp->mask) {
                        // Color profile set for this context?
                        if (logMessage->logContext == cp->context) {
                            colorProfile = cp;

                            // Stop searching
                            break;
                        }

                        // Check if SG_LOG_CONTEXT_ALL was specified as a default color for this flag
                        if (cp->context == SG_LOG_CONTEXT_ALL) {
                            colorProfile = cp;

                            // We don't break to keep searching for more specific color profiles for the context
                        }
                    }
                }
            }
        }

        // Convert log message to C string.
        //
        // We use the stack instead of the heap for speed if possible.
        // But we're extra cautious to avoid a stack overflow.

        NSUInteger msgLen = [logMsg lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        const BOOL useStack = msgLen < (1024 * 4);

        char msgStack[useStack ? (msgLen + 1) : 1]; // Analyzer doesn't like zero-size array, hence the 1
        char *msg = useStack ? msgStack : (char *)malloc(msgLen + 1);

        if (msg == NULL) {
            return;
        }

        BOOL logMsgEnc = [logMsg getCString:msg maxLength:(msgLen + 1) encoding:NSUTF8StringEncoding];

        if (!logMsgEnc) {
            if (!useStack && msg != NULL) {
                free(msg);
            }

            return;
        }

        // Write the log message to STDERR

        if (isFormatted) {
            // The log message has already been formatted.
            int iovec_len = (_automaticallyAppendNewlineForCustomFormatters) ? 5 : 4;
            struct iovec v[iovec_len];

            if (colorProfile) {
                v[0].iov_base = colorProfile->fgCode;
                v[0].iov_len = colorProfile->fgCodeLen;

                v[1].iov_base = colorProfile->bgCode;
                v[1].iov_len = colorProfile->bgCodeLen;

                v[iovec_len - 1].iov_base = colorProfile->resetCode;
                v[iovec_len - 1].iov_len = colorProfile->resetCodeLen;
            } else {
                v[0].iov_base = "";
                v[0].iov_len = 0;

                v[1].iov_base = "";
                v[1].iov_len = 0;

                v[iovec_len - 1].iov_base = "";
                v[iovec_len - 1].iov_len = 0;
            }

            v[2].iov_base = (char *)msg;
            v[2].iov_len = msgLen;

            if (_automaticallyAppendNewlineForCustomFormatters) {
                v[3].iov_base = "\n";
                v[3].iov_len = (msg[msgLen] == '\n') ? 0 : 1;
            }

            writev(STDERR_FILENO, v, iovec_len);
        } else {
            // The log message is unformatted, so apply standard NSLog style formatting.

            int len;
            char ts[24] = "";
            size_t tsLen = 0;

            // Calculate timestamp.
            // The technique below is faster than using NSDateFormatter.
            if (logMessage->timestamp) {
                NSDateComponents *components = [[NSCalendar autoupdatingCurrentCalendar] components:_calendarUnitFlags fromDate:logMessage->timestamp];

                NSTimeInterval epoch = [logMessage->timestamp timeIntervalSinceReferenceDate];
                int milliseconds = (int)((epoch - floor(epoch)) * 1000);

                len = snprintf(ts, 24, "%04ld-%02ld-%02ld %02ld:%02ld:%02ld:%03d", // yyyy-MM-SG HH:mm:ss:SSS
                               (long)components.year,
                               (long)components.month,
                               (long)components.day,
                               (long)components.hour,
                               (long)components.minute,
                               (long)components.second, milliseconds);

                tsLen = (NSUInteger)MAX(MIN(24 - 1, len), 0);
            }

            // Calculate thread ID
            //
            // How many characters do we need for the thread id?
            // logMessage->machThreadID is of type mach_port_t, which is an unsigned int.
            //
            // 1 hex char = 4 bits
            // 8 hex chars for 32 bit, plus ending '\0' = 9

            char tid[9];
            len = snprintf(tid, 9, "%x", logMessage->machThreadID);

            size_t tidLen = (NSUInteger)MAX(MIN(9 - 1, len), 0);

            // Here is our format: "%s %s[%i:%s] %s", timestamp, appName, processID, threadID, logMsg

            struct iovec v[13];

            if (colorProfile) {
                v[0].iov_base = colorProfile->fgCode;
                v[0].iov_len = colorProfile->fgCodeLen;

                v[1].iov_base = colorProfile->bgCode;
                v[1].iov_len = colorProfile->bgCodeLen;

                v[12].iov_base = colorProfile->resetCode;
                v[12].iov_len = colorProfile->resetCodeLen;
            } else {
                v[0].iov_base = "";
                v[0].iov_len = 0;

                v[1].iov_base = "";
                v[1].iov_len = 0;

                v[12].iov_base = "";
                v[12].iov_len = 0;
            }

            v[2].iov_base = ts;
            v[2].iov_len = tsLen;

            v[3].iov_base = " ";
            v[3].iov_len = 1;

            v[4].iov_base = _app;
            v[4].iov_len = _appLen;

            v[5].iov_base = "[";
            v[5].iov_len = 1;

            v[6].iov_base = _pid;
            v[6].iov_len = _pidLen;

            v[7].iov_base = ":";
            v[7].iov_len = 1;

            v[8].iov_base = tid;
            v[8].iov_len = MIN((size_t)8, tidLen); // snprintf doesn't return what you might think

            v[9].iov_base = "] ";
            v[9].iov_len = 2;

            v[10].iov_base = (char *)msg;
            v[10].iov_len = msgLen;

            v[11].iov_base = "\n";
            v[11].iov_len = (msg[msgLen] == '\n') ? 0 : 1;

            writev(STDERR_FILENO, v, 13);
        }

        if (!useStack) {
            free(msg);
        }
    }
}

- (NSString *)loggerName {
    return @"cocoa.lumberjack.ttyLogger";
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation SGTTYLoggerColorProfile

- (instancetype)initWithForegroundColor:(SGColor *)fgColor backgroundColor:(SGColor *)bgColor flag:(int)aMask context:(int)ctxt {
    if ((self = [super init])) {
        mask = aMask;
        context = ctxt;

        CGFloat r, g, b;

        if (fgColor) {
            [SGTTYLogger getRed:&r green:&g blue:&b fromColor:fgColor];

            fg_r = (uint8_t)(r * 255.0f);
            fg_g = (uint8_t)(g * 255.0f);
            fg_b = (uint8_t)(b * 255.0f);
        }

        if (bgColor) {
            [SGTTYLogger getRed:&r green:&g blue:&b fromColor:bgColor];

            bg_r = (uint8_t)(r * 255.0f);
            bg_g = (uint8_t)(g * 255.0f);
            bg_b = (uint8_t)(b * 255.0f);
        }

        if (fgColor && isaColorTTY) {
            // Map foreground color to closest available shell color

            fgCodeIndex = [SGTTYLogger codeIndexForColor:fgColor];
            fgCodeRaw   = [codes_fg objectAtIndex:fgCodeIndex];

            NSString *escapeSeq = @"\033[";

            NSUInteger len1 = [escapeSeq lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
            NSUInteger len2 = [fgCodeRaw lengthOfBytesUsingEncoding:NSUTF8StringEncoding];

            BOOL escapeSeqEnc = [escapeSeq getCString:(fgCode)      maxLength:(len1 + 1) encoding:NSUTF8StringEncoding];
            BOOL fgCodeRawEsc = [fgCodeRaw getCString:(fgCode + len1) maxLength:(len2 + 1) encoding:NSUTF8StringEncoding];

            if (!escapeSeqEnc || !fgCodeRawEsc) {
                return nil;
            }

            fgCodeLen = len1 + len2;
        } else if (fgColor && isaXcodeColorTTY) {
            // Convert foreground color to color code sequence

            const char *escapeSeq = XCODE_COLORS_ESCAPE_SEQ;

            int result = snprintf(fgCode, 24, "%sfg%u,%u,%u;", escapeSeq, fg_r, fg_g, fg_b);
            fgCodeLen = (NSUInteger)MAX(MIN(result, (24 - 1)), 0);
        } else {
            // No foreground color or no color support

            fgCode[0] = '\0';
            fgCodeLen = 0;
        }

        if (bgColor && isaColorTTY) {
            // Map background color to closest available shell color

            bgCodeIndex = [SGTTYLogger codeIndexForColor:bgColor];
            bgCodeRaw   = [codes_bg objectAtIndex:bgCodeIndex];

            NSString *escapeSeq = @"\033[";

            NSUInteger len1 = [escapeSeq lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
            NSUInteger len2 = [bgCodeRaw lengthOfBytesUsingEncoding:NSUTF8StringEncoding];

            BOOL escapeSeqEnc = [escapeSeq getCString:(bgCode)      maxLength:(len1 + 1) encoding:NSUTF8StringEncoding];
            BOOL bgCodeRawEsc = [bgCodeRaw getCString:(bgCode + len1) maxLength:(len2 + 1) encoding:NSUTF8StringEncoding];

            if (!escapeSeqEnc || !bgCodeRawEsc) {
                return nil;
            }

            bgCodeLen = len1 + len2;
        } else if (bgColor && isaXcodeColorTTY) {
            // Convert background color to color code sequence

            const char *escapeSeq = XCODE_COLORS_ESCAPE_SEQ;

            int result = snprintf(bgCode, 24, "%sbg%u,%u,%u;", escapeSeq, bg_r, bg_g, bg_b);
            bgCodeLen = (NSUInteger)MAX(MIN(result, (24 - 1)), 0);
        } else {
            // No background color or no color support

            bgCode[0] = '\0';
            bgCodeLen = 0;
        }

        if (isaColorTTY) {
            resetCodeLen = (NSUInteger)MAX(snprintf(resetCode, 8, "\033[0m"), 0);
        } else if (isaXcodeColorTTY) {
            resetCodeLen = (NSUInteger)MAX(snprintf(resetCode, 8, XCODE_COLORS_RESET), 0);
        } else {
            resetCode[0] = '\0';
            resetCodeLen = 0;
        }
    }

    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:
            @"<SGTTYLoggerColorProfile: %p mask:%i ctxt:%i fg:%u,%u,%u bg:%u,%u,%u fgCode:%@ bgCode:%@>",
            self, mask, context, fg_r, fg_g, fg_b, bg_r, bg_g, bg_b, fgCodeRaw, bgCodeRaw];
}

@end
