//
//  ViewController.m
//  NotificationWithSubThread
//
//  Created by Mr.LuDashi on 2017/8/22.
//  Copyright © 2017年 ZeluLi. All rights reserved.
//

#import "ViewController.h"
#import "SecondViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"register notifcation thread = %@", [NSThread currentThread]);
    
    //往通知中心添加观察者
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleNotification:)
                                                 name:@"MyNAME" object:nil];
    
    //创建子线程，在子线程中发送通知
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"post notification thread = %@", [NSThread currentThread]);
        [[NSNotificationCenter defaultCenter] postNotificationName:@"MyNAME" object:nil userInfo:nil];
    });
}

/**
 处理通知的方法

 @param notification notification
 */
- (void)handleNotification:(NSNotification *)notification {
    //打印处理通知方法的线程
    NSLog(@"handle notification thread = %@", [NSThread currentThread]);
}



- (IBAction)tapPushButton:(id)sender {
    [self.navigationController pushViewController:[SecondViewController new] animated:YES];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
