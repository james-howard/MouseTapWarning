//
//  MouseTapWarning.m
//  MouseTapWarning
//
//  Created by James Howard on 11/14/19.
//  Copyright © 2019 jh. All rights reserved.
//

#import "MouseTapWarning.h"

static NSString *const SuppressDefaultsKey = @"MouseTapIgnoreWarning";

#if __MAC_OS_X_VERSION_MAX_ALLOWED < 101400
static const NSInteger NSControlStateValueOn = NSOnState;
#endif

@interface MouseTapWarning () <NSTableViewDelegate, NSTableViewDataSource>

@property (nonatomic) NSTableView *tableView;
@property (nonatomic, copy) NSArray /*NSRunningApplication*/ *tapApplications;

@end

@implementation MouseTapWarning

+ (void)warnIfNeeded {
    MouseTapWarning *warning = [MouseTapWarning new];
    [warning showIfNeeded];
}

- (instancetype)init {
    if (self = [super init]) {
        self.tapApplications = [[self class] findTaps];
        for (NSRunningApplication *app in self.tapApplications) {
            [app addObserver:self forKeyPath:@"terminated" options:0 context:NULL];
        }
    }
    return self;
}

- (void)dealloc {
    for (NSRunningApplication *app in self.tapApplications) {
        [app removeObserver:self forKeyPath:@"terminated"];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    [self.tableView reloadData];
}

static BOOL CanTerminateOtherApps()
{
    static dispatch_once_t onceToken;
    static BOOL isSandboxed;
    dispatch_once(&onceToken, ^{
        isSandboxed = [[[[NSProcessInfo processInfo] environment] objectForKey: @"HOME"] rangeOfString: @"/Library/Containers/"].location != NSNotFound;
    });
    return !isSandboxed;
}

- (void)showIfNeeded {
//    if (self.tapApplications.count == 0 || [[NSUserDefaults standardUserDefaults] boolForKey:SuppressDefaultsKey]) {
//        return;
//    }

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 300, 100)];
    NSTableView *table = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 300, 100)];
    self.tableView = table;

    NSTableColumn *iconCol = [[NSTableColumn alloc] initWithIdentifier:@"icon"];
    iconCol.minWidth = 24.0;
    iconCol.maxWidth = iconCol.minWidth;
    iconCol.width = iconCol.minWidth;
    [iconCol setDataCell:[NSImageCell new]];
    [table addTableColumn:iconCol];

    NSTableColumn *nameCol = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    [table addTableColumn:nameCol];

    table.headerView = nil;
    table.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;

    table.delegate = self;
    table.dataSource = self;


    [scroll setBorderType:NSLineBorder];
    [scroll setHasVerticalScroller:YES];
    [scroll setDocumentView:table];

    NSAlert *alert = [NSAlert new];

    [alert setMessageText:NSLocalizedStringWithDefaultValue(@"mouse-tap-app-alert-title", NULL, [NSBundle mainBundle], @"Mouse Tap", @"Alert title for mouse tap warning")];
    [alert setInformativeText:NSLocalizedStringWithDefaultValue(@"mouse-tap-app-alert-text", NULL, [NSBundle mainBundle], @"The following applications may affect mouse input during gameplay.", @"Alert text for mouse tap warning")];

    [alert addButtonWithTitle:NSLocalizedStringWithDefaultValue(@"continue-mouse-tap-app-button", NULL, [NSBundle mainBundle], @"OK", @"Continue without quitting applications that are tapping the mouse.")];

    if (CanTerminateOtherApps()) {
        [alert addButtonWithTitle:NSLocalizedStringWithDefaultValue(@"quit-mouse-tap-app-button", NULL, [NSBundle mainBundle], @"Quit Applications", @"Quit all applications that are tapping the mouse button title")];
    }

//    [alert setShowsSuppressionButton:YES];

    [alert setAccessoryView:scroll];

    [table reloadData];

    NSModalResponse response = [alert runModal];

    BOOL suppress = [[alert suppressionButton] state] == NSControlStateValueOn;

    if (suppress) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SuppressDefaultsKey];
    }

    if (response == NSAlertSecondButtonReturn) {
        // Quit Applications
        [self.tapApplications makeObjectsPerformSelector:@selector(terminate)];
    }

    exit(0);
}

+ (NSArray *)findTaps {
    const size_t TAP_MAX = 128;
    CGEventTapInformation info[TAP_MAX];
    uint32_t tapCount = 0;
    CGGetEventTapList(TAP_MAX, info, &tapCount);

    NSMutableDictionary *apps = [NSMutableDictionary new];
    for (NSRunningApplication *app in [[NSWorkspace sharedWorkspace] runningApplications])
    {
        apps[@(app.processIdentifier)] = app;
    }

    NSMutableSet *taps = [NSMutableSet new];
    for (uint32_t i = 0; i < tapCount && i < TAP_MAX; i++)
    {
        if ((info[i].eventsOfInterest & (CGEventMaskBit(kCGEventMouseMoved) | CGEventMaskBit(kCGEventLeftMouseDown))) && info[i].options != kCGEventTapOptionListenOnly)
        {
            NSRunningApplication *app = apps[@(info[i].tappingProcess)];
            if (app) {
                [taps addObject:app];
            }
        }
    }

    return [taps allObjects];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.tapApplications.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSRunningApplication *app = self.tapApplications[row];
    if ([tableColumn.identifier isEqualToString:@"icon"]) {
        return app.icon;
    } else {
        return app.localizedName;
    }
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSRunningApplication *app = self.tapApplications[row];
    [((NSCell *)cell) setEnabled:!app.terminated];
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    return NO;
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    return NO;
}

@end
