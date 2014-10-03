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
        
		[self swizzler];
    }
    return self;
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

	if (workspaceName != nil && [workspaceName length] > 0 && windowTitle != nil && [windowTitle length] > 0) {
		NSString *newTitle = [NSString stringWithFormat:@"%@ - %@", workspaceName, windowTitle];
		[window setTitle:newTitle];
	}
}

@end