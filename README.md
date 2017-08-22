# NotificationWithSubThread
NotificationWithSubThread
#### 在主线程中注册观察者，在子线程中发送通知，是发送通知的线程处理的通知事件
![](https://github.com/lizelu/NotificationWithSubThread/blob/master/firstVC.png)

#### 在发送通知的子线程处理通知的事件时，将NSNotification暂存，然后通过MachPort往相应线程的RunLoop中发送事件。相应的线程收到该事件后，取出在队列中暂存的NSNotification, 然后在当前线程中调用处理通知的方法。下方是运行结果。
![](https://github.com/lizelu/NotificationWithSubThread/blob/master/secondVC.png)
