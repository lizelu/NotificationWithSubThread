//
//  SecondViewController.m
//  NotificationWithSubThread
//
//  Created by Mr.LuDashi on 2017/8/22.
//  Copyright © 2017年 ZeluLi. All rights reserved.
//

#import "SecondViewController.h"

@interface SecondViewController ()<NSMachPortDelegate>
@property (nonatomic, strong) NSMutableArray    *notificationsQueue;    //存储子线程发出的通知的队列
@property (nonatomic, strong) NSThread          *mainThread;            // 处理通知事件的预期线程
@property (nonatomic, strong) NSLock            *lock;                  // 用于对通知队列加锁的锁对象，避免线程冲突
@property (nonatomic, strong) NSMachPort        *mackPort;              // 用于向期望线程发送信号的通信端口
@end

@implementation SecondViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    //打印注册观察者的线程，此处也就是主线程
    NSLog(@"register notificaton thread = %@", [NSThread currentThread]);
   
    [self setUpThreadingSupport]; // 对相关的成员属性进行初始
    
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


/**
 对相关的成员属性进行初始
 */
- (void) setUpThreadingSupport {
    if (self.notificationsQueue) {
        return;
    }
    self.notificationsQueue = [[NSMutableArray alloc] init];    //队列：用来暂存其他线程发出的通知
    self.lock = [[NSLock alloc] init];                          //负责栈操作的原子性
    self.mainThread = [NSThread currentThread];                 //记录处理通知的线程
    self.mackPort = [[NSMachPort alloc] init];                  //负责往处理通知的线程所对应的RunLoop中发送消息的
    [self.mackPort setDelegate:self];
    
    [[NSRunLoop currentRunLoop] addPort:self.mackPort           //将Mac Port添加到处理通知的线程中的RunLoop中
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
    
    //在子线程中对notificationsQueue队列操作时，需要加锁，保持队列中数据的正确性
    [self.lock lock];
    
    //依次取出队列中所暂存的Notification，然后在当前线程中处理该通知
    while ([self.notificationsQueue count]) {
        NSNotification *notification = [self.notificationsQueue objectAtIndex:0];
        
        [self.notificationsQueue removeObjectAtIndex:0]; //取出队列中第一个值
        
        [self.lock unlock];
        [self processNotification:notification];    //处理从队列中取出的通知
        [self.lock lock];
        
    };
    
    [self.lock unlock];
}


- (void)processNotification:(NSNotification *)notification {
    
    if ([NSThread currentThread] == _mainThread) {
        //处理出队列中的通知
        NSLog(@"handle notification thread = %@", [NSThread currentThread]);
        NSLog(@"process notification");
        
    } else { //在子线程中收到通知后，将收到的通知放入到队列中存储，然后给主线程的RunLoop发送处理通知的消息
        NSLog(@"transfer notification thread = %@", [NSThread currentThread]);
        
        // Forward the notification to the correct thread.
        [self.lock lock];
        [self.notificationsQueue addObject:notification];    //将其他线程中发过来的通知不做处理，入队列暂存
        [self.lock unlock];
        
        //通过MacPort给处理通知的线程发送通知，使其处理队列中所暂存的队列
        [self.mackPort sendBeforeDate:[NSDate date]
                           components:nil
                                 from:nil
                             reserved:0];

    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
@end
