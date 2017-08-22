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
    self.notifications      = [[NSMutableArray alloc] init];    //队列：用来暂存其他线程发出的通知
    self.notificationLock   = [[NSLock alloc] init];            //负责栈操作的原子性
    self.notificationThread = [NSThread currentThread];         //记录处理通知的线程
    
    self.notificationPort = [[NSMachPort alloc] init];          //负责往处理通知的线程所对应的RunLoop中发送消息的
    [self.notificationPort setDelegate:self];
    
    [[NSRunLoop currentRunLoop] addPort:self.notificationPort   //将Mac Port添加到处理通知的线程中的RunLoop中
                                forMode:(__bridge NSString *)kCFRunLoopCommonModes];
}


/**
 从子线程收到Mach Port发出的消息后所执行的方法
 在该方法中从队列中获取子线程中发出的NSNotification
 然后使用当前线程来处理该通知

 RunLoop收到Mac Port发出的消息时所执行的回调方法。
 */
- (void)handleMachMessage:(void *)msg {
    
    NSLog(@"handle Mach Message thread = %@", [NSThread currentThread]);
    
    [self.notificationLock lock];
    
    //依次取出队列中所暂存的Notification，然后在当前线程中处理该通知
    while ([self.notifications count]) {
        NSNotification *notification = [self.notifications objectAtIndex:0];
        
        [self.notifications removeObjectAtIndex:0]; //取出队列中第一个值
        
        [self.notificationLock unlock];
        [self processNotification:notification];    //处理从队列中取出的通知
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
        [self.notifications addObject:notification];    //将其他线程中发过来的通知不做处理，入队列暂存
        [self.notificationLock unlock];
        
        //通过MacPort给处理通知的线程发送通知，使其处理队列中所暂存的队列
        [self.notificationPort sendBeforeDate:[NSDate date]
                                   components:nil
                                         from:nil
                                     reserved:0];
    } else {
        //处理出队列中的通知
        
        NSLog(@"handle notification thread = %@", [NSThread currentThread]);
        NSLog(@"process notification");
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
@end
