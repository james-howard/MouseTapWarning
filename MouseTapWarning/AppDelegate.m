//
//  AppDelegate.m
//  MouseTapWarning
//
//  Created by James Howard on 11/14/19.
//  Copyright © 2019 jh. All rights reserved.
//

#import "AppDelegate.h"
#import "MouseTapWarning.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [MouseTapWarning warnIfNeeded];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
