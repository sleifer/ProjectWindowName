//
//  ProjectWindowName.m
//  ProjectWindowName
//
//  Created by Simeon Leifer on 10/2/14.
//    Copyright (c) 2014 Simeon Leifer. All rights reserved.
//

#import "ProjectWindowName.h"

#import <objc/objc-runtime.h>

static ProjectWindowName *sharedPlugin;

@interface ProjectWindowName()

@property (nonatomic, strong, readwrite) NSBundle *bundle;
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
        
        // Create menu items, initialize UI, etc.

        // Sample Menu Item:
        NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
        if (menuItem) {
            [[menuItem submenu] addItem:[NSMenuItem separatorItem]];
            NSMenuItem *actionMenuItem = [[NSMenuItem alloc] initWithTitle:@"Do Action" action:@selector(doMenuAction) keyEquivalent:@""];
            [actionMenuItem setTarget:self];
            [[menuItem submenu] addItem:actionMenuItem];
        }
		
		[self swizzler];
    }
    return self;
}

- (void)tryFScript
{
	NSBundle* bundle = nil;
	BOOL available = NO;
	bundle = [NSBundle bundleWithPath:@"/Library/Frameworks/FScript.framework"];
	if (bundle) {
		available = [bundle load];
	}
	if (available) {
		Class menuClass = NSClassFromString(@"FScriptMenuItem");
		
		if (menuClass) {
			[[NSApp mainMenu] addItem:[[menuClass alloc] init]];
		}
	}
}

- (void)swizzler {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		Class IDEWorkspaceWindowControllerClass = NSClassFromString (@"IDEWorkspaceWindowController");
		
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

// Sample Action, for menu item:
- (void)doMenuAction
{
    NSAlert *alert = [NSAlert alertWithMessageText:@"Hello, World" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
    [alert runModal];
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
	NSLog(@"xxx__updateWindowTitle: %@ [%@]", self, NSStringFromClass([self class]));
	
	NSWindow *window = [self performSelector:@selector(window)];
	NSString *windowTitle = [window title];
	NSLog(@"window: %@", window);
	NSLog(@"window title: %@", [window title]);
	NSLog(@"window representedURL: %@", [window representedURL]);
	
	id workspace = object_getIvar(self, class_getInstanceVariable([self class], "_workspace"));
	NSLog(@"_workspace %@", workspace);

	NSString *workspaceName = [workspace performSelector:@selector(name)];
	NSLog(@"representingTitle: %@", [workspace performSelector:@selector(representingTitle)]);
	NSLog(@"representingFilePath: %@", [workspace performSelector:@selector(representingFilePath)]);
	NSLog(@"name: %@", [workspace performSelector:@selector(name)]);
	NSLog(@"displayName: %@", [workspace performSelector:@selector(displayName)]);

	NSString *newTitle = [NSString stringWithFormat:@"%@ - %@", workspaceName, windowTitle];
	[window setTitle:newTitle];
	NSLog(@"window title: %@", [window title]);
	NSLog(@"window representedURL: %@", [window representedURL]);
	NSLog(@"-------------");
}

@end