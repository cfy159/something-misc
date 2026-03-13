# Python中的异步编程asyncio库

asyncio是python中的一个内置库，主要用来实现单线程并发代码，
它是用过协程来实现的，提供了基于事件的并发模型。



## asyncio的使用

### 1新版本 API

```python
import asyncio
		
async def do_sth():
    pass

# 调用这个函数do_sth不会执行，会返回一个协程对象
def main():	
    do_sth()

# a) 需要用run来执行
asyncio.run(do_sth())

# b) 在别的异步函数中被调用
async def main():
	await do_sth() # 异步函数通过await来调用，且await只能在异步函数中使用
    
asyncio.run(main())
```



### 2旧版本 API

```python
# 获取当前的事件循环
loop = asyncio.get_event_loop()
# 当前事件运行一个任务
loop.run_until_complete(main())
```



### 3同时执行多个异步函数

#### 1 新版本 API

1) create_task + await

```python
aync def main():
	# a) 先将异步函数用create_task创建成task
	task1 = asyncio.create_task(do_sth1())
	task2 = asyncio.create_task(do_sth2())
	task3 = asyncio.create_task(do_sth3())
	# b) 使用await启动所有任务
	await task1
	await task2
	await task3
    
# 运行异步函数
asyncio.run(main())
```

2) gather

```python
async def main():
    await asyncio.gather(
        do_sth1(),
        do_sth2(),
        do_sth3()
    )
asyncio.run(main())
```



#### 2 旧版本 API

```python
loop = asyncio.get_event_loop()
tasks = [
    do_sth1(),
    do_sth2(),
    do_sth3()
]
loop.run_until_complete(asyncio.wait(tasks))
loop.close()
```

​	

### 4事件循环的核心是一个Queue,还可以通过下面方法来操作事件循环

```python
loop = asyncio.new_event_loop()	# 新建一个事件循环
asyncio.set_event_loop() # 手动设置为当前线程的事件循环(多应用与多线程环境中)
loop = asyncio.get_event_loop() # 获取当前线程的事件循环
loop.run_until_complete(asyncio.sleep(2)) # 运行协程直到完成
task = loop.create_task(asyncio.sleep(2)) # 将协程包装成任务
loop.close() # 关闭协程
loop.run_forever() # 一直运行事件循环，直到loop.stop()
loop.stop() # 暂停
loop.is_running()
loop.is_closed()
```

