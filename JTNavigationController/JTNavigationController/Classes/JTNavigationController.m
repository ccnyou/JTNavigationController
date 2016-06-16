//
//  JTNavigationController.m
//  JTNavigationController
//
//  Created by Tian on 16/1/23.
//  Copyright © 2016年 TianJiaNan. All rights reserved.
//

#import "JTNavigationController.h"
#import "UIViewController+JTNavigationExtension.h"

#define kDefaultBackImageName @"backImage"

@interface JTNavigationController () <UINavigationControllerDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIPanGestureRecognizer *popPanGesture;
@property (nonatomic, strong) id popGestureDelegate;
@property (nonatomic, assign) UINavigationControllerOperation jt_operation;

@end

#pragma mark - JTWrapNavigationController

@interface JTWrapNavigationController : UINavigationController

@end

@implementation JTWrapNavigationController

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    self.jt_navigationController.jt_operation = UINavigationControllerOperationPop;
    return [self.navigationController popViewControllerAnimated:animated];
}

- (NSArray<UIViewController *> *)popToRootViewControllerAnimated:(BOOL)animated {
    self.jt_navigationController.jt_operation = UINavigationControllerOperationPop;
    return [self.navigationController popToRootViewControllerAnimated:animated];
}

- (NSArray<UIViewController *> *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated {
    JTNavigationController *jt_navigationController = viewController.jt_navigationController;
    jt_navigationController.jt_operation = UINavigationControllerOperationPop;
    NSInteger index = [jt_navigationController.jt_viewControllers indexOfObject:viewController];
    return [self.navigationController popToViewController:jt_navigationController.viewControllers[index] animated:animated];
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (![self.navigationController isKindOfClass:[JTNavigationController class]]) {
        return;
    }
    
    viewController.jt_navigationController = (JTNavigationController *)self.navigationController;
    viewController.jt_fullScreenPopGestureEnabled = viewController.jt_navigationController.fullScreenPopGestureEnabled;
    viewController.jt_navigationController.jt_operation = UINavigationControllerOperationPush;
    
    UIImage *backButtonImage = viewController.jt_navigationController.backButtonImage;
    if (!backButtonImage) {
        backButtonImage = [UIImage imageNamed:kDefaultBackImageName];
    }
    
    viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:backButtonImage
                                                                                       style:UIBarButtonItemStylePlain
                                                                                      target:viewController
                                                                                      action:@selector(jt_didTapBackButton:)];
    
    JTWrapViewController* wrapController = [JTWrapViewController wrapViewControllerWithViewController:viewController];
    [self.navigationController pushViewController:wrapController animated:animated];
}

-(void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion{
    [self.navigationController dismissViewControllerAnimated:flag completion:completion];
    self.viewControllers.firstObject.jt_navigationController = nil;
}

@end

#pragma mark - JTWrapViewController

static NSValue *jt_tabBarRectValue;

@implementation JTWrapViewController

+ (JTWrapViewController *)wrapViewControllerWithViewController:(UIViewController *)viewController {
    if (!viewController) {
        NSLog(@"%s %d Warning: wrapViewControllerWithViewController:nil", __FUNCTION__, __LINE__);
        return nil;
    }
    
    JTWrapNavigationController *wrapNavController = [[JTWrapNavigationController alloc] init];
    wrapNavController.viewControllers = @[viewController];
    
    JTWrapViewController *wrapViewController = [[JTWrapViewController alloc] init];
    [wrapViewController.view addSubview:wrapNavController.view];
    [wrapViewController addChildViewController:wrapNavController];
    
    return wrapViewController;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    if (self.tabBarController && !jt_tabBarRectValue) {
        jt_tabBarRectValue = [NSValue valueWithCGRect:self.tabBarController.tabBar.frame];
    }
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (self.tabBarController && [self rootViewController].hidesBottomBarWhenPushed) {
        self.tabBarController.tabBar.frame = CGRectZero;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.tabBarController.tabBar.translucent = YES;
    if (self.tabBarController && !self.tabBarController.tabBar.hidden && jt_tabBarRectValue) {
        self.tabBarController.tabBar.frame = jt_tabBarRectValue.CGRectValue;
    }
}

- (BOOL)jt_fullScreenPopGestureEnabled {
    return [self rootViewController].jt_fullScreenPopGestureEnabled;
}

- (BOOL)hidesBottomBarWhenPushed {
    return [self rootViewController].hidesBottomBarWhenPushed;
}

- (UITabBarItem *)tabBarItem {
    return [self rootViewController].tabBarItem;
}

- (NSString *)title {
    return [self rootViewController].title;
}

- (UIViewController *)childViewControllerForStatusBarStyle {
    return [self rootViewController];
}

- (UIViewController *)childViewControllerForStatusBarHidden {
    return [self rootViewController];
}

- (UIViewController *)rootViewController {
    JTWrapNavigationController *wrapNavController = self.childViewControllers.firstObject;
    return wrapNavController.viewControllers.firstObject;
}

@end

#pragma mark - JTNavigationController

@implementation JTNavigationController {
    BOOL _shouldNextGestureFailed;
}

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController {
    if (self = [super init]) {
        rootViewController.jt_navigationController = self;
        self.viewControllers = @[[JTWrapViewController wrapViewControllerWithViewController:rootViewController]];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        self.viewControllers.firstObject.jt_navigationController = self;
        self.viewControllers = @[[JTWrapViewController wrapViewControllerWithViewController:self.viewControllers.firstObject]];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setNavigationBarHidden:YES];
    self.delegate = self;
    
    self.popGestureDelegate = self.interactivePopGestureRecognizer.delegate;
    SEL action = NSSelectorFromString(@"handleNavigationTransition:");
    self.popPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self.popGestureDelegate action:action];
    self.popPanGesture.maximumNumberOfTouches = 1;
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    UIViewController* result = [super popViewControllerAnimated:animated];
    self.jt_operation = UINavigationControllerOperationPop;
    
    return result;
}

#pragma mark - 横屏控制支持 

- (BOOL)shouldAutorotate {
    if (self.jt_viewControllers.count > 0) {
        UIViewController* root = [self.jt_viewControllers firstObject];
        return [root shouldAutorotate];
    }
    
    return [super shouldAutorotate];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (self.jt_viewControllers.count > 0) {
        UIViewController* root = [self.jt_viewControllers firstObject];
        return [root supportedInterfaceOrientations];
    }
    
    return [super supportedInterfaceOrientations];
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    if (self.jt_viewControllers.count > 0) {
        UIViewController* root = [self.jt_viewControllers firstObject];
        return [root preferredInterfaceOrientationForPresentation];
    }
    
    return [super preferredInterfaceOrientationForPresentation];
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    
    BOOL isRootVC = viewController == navigationController.viewControllers.firstObject;
    
    if (viewController.jt_fullScreenPopGestureEnabled) {
        if (isRootVC) {
            [self.view removeGestureRecognizer:self.popPanGesture];
        } else {
            [self.view addGestureRecognizer:self.popPanGesture];
        }
        self.interactivePopGestureRecognizer.delegate = self.popGestureDelegate;
        self.interactivePopGestureRecognizer.enabled = NO;
    } else {
        [self.view removeGestureRecognizer:self.popPanGesture];
        self.interactivePopGestureRecognizer.delegate = self;
        self.interactivePopGestureRecognizer.enabled = !isRootVC;
    }
    
}

#pragma mark - UIGestureRecognizerDelegate

//修复有水平方向滚动的ScrollView时边缘返回手势失效的问题
-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return [gestureRecognizer isKindOfClass:UIScreenEdgePanGestureRecognizer.class];
}

#pragma mark - Getter

- (NSArray *)jt_viewControllers {
    NSMutableArray *viewControllers = [NSMutableArray array];
    for (JTWrapViewController *wrapViewController in self.viewControllers) {
        [viewControllers addObject:wrapViewController.rootViewController];
    }
    return viewControllers.copy;
}

@end


@implementation UINavigationController (JTExtention)

- (UINavigationControllerOperation)jt_operation {
    if ([self isKindOfClass:[JTNavigationController class]]) {
        JTNavigationController* controller = (JTNavigationController *)self;
        return controller.jt_operation;
    }
    
    return UINavigationControllerOperationNone;
}

- (NSArray *)jt_popViewControllerTwiceAnimated:(BOOL)animated {
    if (![self.navigationController isKindOfClass:[JTNavigationController class]]) {
        return nil;
    }
    
    JTNavigationController* jt_navigationController = (JTNavigationController *)self.navigationController;
    NSArray* viewControllers = jt_navigationController.jt_viewControllers;
    NSInteger count = viewControllers.count;
    NSInteger index = count - 3;
    if (index < 0) {
        // 出错了，没办法pop两次
        UIViewController* controller = [self popViewControllerAnimated:animated];
        NSArray* controllers = @[controller];
        return controllers;
    }
    
    UIViewController* viewController = [viewControllers objectAtIndex:index];
    return [self popToViewController:viewController animated:animated];
}

@end
