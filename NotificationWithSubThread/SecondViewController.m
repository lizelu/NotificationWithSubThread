//
//  SecondViewController.m
//  NotificationWithSubThread
//
//  Created by Mr.LuDashi on 2017/8/22.
//  Copyright © 2017年 ZeluLi. All rights reserved.
//

#import "SecondViewController.h"

@interface SecondViewController ()<NSMachPortDelegate>
@property (nonatomic, strong) NSMutableArray    *notifications;         // 通知队列
@property (nonatomic, strong) NSThread          *notificationThread;    // 期望线程
@property (nonatomic, strong) NSLock            *notificationLock;      // 用于对通知队列加锁的锁对象，避免线程冲突
@property (nonatomic, strong) NSMachPort        *notificationPort;      // 用于向期望线程发送信号的通信端口
@end

@implementation SecondViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    NSLog(@"register notificaton thread = %@", [NSThread currentThread]);
   
    [self setUpThreadingSupport];
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(processNotification:)
     name:@"NotificationName"
     object:nil];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"post notificaton thread = %@", [NSThread currentThread]);
        [[NSNotificationCenter defaultCenter] postNotificationName:@"NotificationName" object:nil userInfo:nil];
        
    });
}

- (void) setUpThreadingSupport {
    if (self.notifications) {
        return;
    }
    self.notifications      = [[NSMutableArray alloc] init];
    self.notificationLock   = [[NSLock alloc] init];
    self.notificationThread = [NSThread currentThread];
    
    self.notificationPort = [[NSMachPort alloc] init];
    [self.notificationPort setDelegate:self];
    [[NSRunLoop currentRunLoop] addPort:self.notificationPort
                                forMode:(__bridge NSString *)kCFRunLoopCommonModes];
}


/**
 从子线程收到Mach Port发出的消息后所执行的方法
 在该方法中从队列中获取子线程中发出的NSNotification
 然后使用当前线程来处理该通知

 @param msg <#msg description#>
 */
- (void)handleMachMessage:(void *)msg {
    
    [self.notificationLock lock];
    
    NSLog(@"handle Mach Message thread = %@", [NSThread currentThread]);
    while ([self.notifications count]) {
        NSNotification *notification = [self.notifications objectAtIndex:0];
        [self.notifications removeObjectAtIndex:0];
        [self.notificationLock unlock];
        [self processNotification:notification];
        [self.notificationLock lock];
    };
    
    [self.notificationLock unlock];
}


- (void)processNotification:(NSNotification *)notification {
    
    //在子线程中收到通知后，将收到的通知放入到队列中存储，然后给主线程的RunLoop发送处理通知的消息
    if ([NSThread currentThread] != _notificationThread) {
        NSLog(@"transfer notification thread = %@", [NSThread currentThread]);
        // Forward the notification to the correct thread.
        [self.notificationLock lock];
        [self.notifications addObject:notification];
        [self.notificationLock unlock];
        
        //通过Mac Port来发送消息，使其他线程来处理该通知
        [self.notificationPort sendBeforeDate:[NSDate date]
                                   components:nil
                                         from:nil
                                     reserved:0];
    }
    else {
        // Process the notification here;
        NSLog(@"handle notification thread = %@", [NSThread currentThread]);
        NSLog(@"process notification");
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
@end
