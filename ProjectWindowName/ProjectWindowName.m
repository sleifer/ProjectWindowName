//
// ProjectWindowName.m
//
// Copyright (c) 2014 Simeon Leifer
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

#import "ProjectWindowName.h"

#import <objc/objc-runtime.h>

NSString *const PathModeKey = @"ProjectWindowName_PathModeKey";

typedef NS_ENUM (NSInteger, WindowTitlePathMode) {
    WindowTitlePathMode_FilePath = 0,
    WindowTitlePathMode_ProjectPath
};

static ProjectWindowName *sharedPlugin;

@interface ProjectWindowName ()

@property (nonatomic, strong, readwrite) NSBundle *bundle;
@property (nonatomic, strong, readwrite) NSMenuItem *filePathItem;
@property (nonatomic, strong, readwrite) NSMenuItem *projectPathItem;
@property (nonatomic, assign, readwrite) WindowTitlePathMode titlePathMode;

@end

@implementation ProjectWindowName

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

+ (instancetype)sharedPlugin
{
    return sharedPlugin;
}

- (id)initWithBundle:(NSBundle *)plugin
{
    if (self = [super init]) {
        // reference to plugin's bundle, for resource access
        self.bundle = plugin;

        [self swizzler];
		[self readPathMode];
        [self installMenus];
		[self updateMenus];
    }
    return self;
}

- (void)installMenus
{
    NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
    if (menuItem) {
        NSMenu *optionsMenu = [[NSMenu alloc] initWithTitle:@"Window Title Path"];
        NSMenuItem *filePathOption = [optionsMenu addItemWithTitle:@"File Path" action:@selector(doFilePathMenuAction) keyEquivalent:@""];
        [filePathOption setTarget:self];
        NSMenuItem *projectPathOption = [optionsMenu addItemWithTitle:@"Project Path" action:@selector(doProjectPathMenuAction) keyEquivalent:@""];
        [projectPathOption setTarget:self];
        self.filePathItem = filePathOption;

        [[menuItem submenu] addItem:[NSMenuItem separatorItem]];
        NSMenuItem *actionMenuItem = [[NSMenuItem alloc] initWithTitle:@"Window Title Path" action:@selector(doMenuAction) keyEquivalent:@""];
        [actionMenuItem setTarget:self];
        [actionMenuItem setSubmenu:optionsMenu];
        [[menuItem submenu] addItem:actionMenuItem];
        self.projectPathItem = projectPathOption;
    }
}

- (void)doMenuAction
{
}

- (void)doFilePathMenuAction
{
	[self setPathMode:WindowTitlePathMode_FilePath];
	[self updateMenus];
	[self refreshAllWindowTitles];
}

- (void)doProjectPathMenuAction
{
	[self setPathMode:WindowTitlePathMode_ProjectPath];
	[self updateMenus];
	[self refreshAllWindowTitles];
}

- (void)updateMenus
{
	if (self.titlePathMode == WindowTitlePathMode_FilePath) {
		[self.filePathItem setState:NSOnState];
		[self.projectPathItem setState:NSOffState];
	} else {
		[self.filePathItem setState:NSOffState];
		[self.projectPathItem setState:NSOnState];
	}
}

- (void)readPathMode
{
	id value = [[NSUserDefaults standardUserDefaults] valueForKey:PathModeKey];
	if (value != nil) {
		self.titlePathMode = (WindowTitlePathMode) [value integerValue];
	} else {
		self.titlePathMode = WindowTitlePathMode_FilePath;
	}
}

- (void)setPathMode:(WindowTitlePathMode)newMode
{
	[[NSUserDefaults standardUserDefaults] setInteger:newMode forKey:PathModeKey];
	self.titlePathMode = newMode;
}

- (void)refreshAllWindowTitles
{
	Class IDEWorkspaceWindowControllerClass = NSClassFromString(@"IDEWorkspaceWindowController");
	NSArray *allControllers = [IDEWorkspaceWindowControllerClass performSelector:@selector(workspaceWindowControllers)];
	for (id ctrl in allControllers) {
		[ctrl performSelector:@selector(_updateWindowTitle)];
	}
}

- (void)swizzler
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class IDEWorkspaceWindowControllerClass = NSClassFromString(@"IDEWorkspaceWindowController");

        [self swizzleClass:IDEWorkspaceWindowControllerClass originalSelector:@selector(_updateWindowTitle) swizzledSelector:@selector(xxx__updateWindowTitle) instanceMethod:YES];
    });
}

- (void)swizzleClass:(Class)class originalSelector:(SEL)originalSelector swizzledSelector:(SEL)swizzledSelector instanceMethod:(BOOL)instanceMethod
{
    if (class) {
        Method originalMethod;
        Method swizzledMethod;
        if (instanceMethod) {
            originalMethod = class_getInstanceMethod(class, originalSelector);
            swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        } else {
            originalMethod = class_getClassMethod(class, originalSelector);
            swizzledMethod = class_getClassMethod(class, swizzledSelector);
        }

        BOOL didAddMethod = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));

        if (didAddMethod) {
            class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

@implementation NSObject (ProjectWindowName)

- (void)xxx__updateWindowTitle
{
    [self xxx__updateWindowTitle];

    NSWindow *window = [self performSelector:@selector(window)];
    NSString *windowTitle = nil;
    if (window != nil) {
        windowTitle = [window title];
    }

    id workspace = object_getIvar(self, class_getInstanceVariable([self class], "_workspace"));
    NSString *workspaceName = nil;
    if (workspace != nil) {
        workspaceName = [workspace performSelector:@selector(name)];
    }

    id representingFilePath = nil;
    if (workspace != nil) {
        representingFilePath = [workspace performSelector:@selector(representingFilePath)];
    }

    NSURL *fileURL = nil;
    if (representingFilePath != nil) {
        fileURL = [representingFilePath performSelector:@selector(fileURL)];
    }

    if (workspaceName != nil && [workspaceName length] > 0 && windowTitle != nil && [windowTitle length] > 0) {
        NSString *newTitle = [NSString stringWithFormat:@"%@ - %@", workspaceName, windowTitle];
		if (sharedPlugin.titlePathMode == WindowTitlePathMode_ProjectPath) {
			[window setRepresentedURL:fileURL];
		}
        [window setTitle:newTitle];
    }
}

@end
