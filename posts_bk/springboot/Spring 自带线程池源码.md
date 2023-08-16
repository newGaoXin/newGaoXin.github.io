# Spring 自带线程池源码

一直很好奇Spring 自带线程池的默认配置是什么样子的

我们知道 SpringBoot 中的自动装配都 AutoConfiguration 的对应类

线程池也有对应的 AutoConfiguration 类：TaskExecutionAutoConfiguration

TaskExecutionAutoConfiguration 类源码

```java

/**
 * {@link EnableAutoConfiguration Auto-configuration} for {@link TaskExecutor}.
 *
 * @author Stephane Nicoll
 * @author Camille Vienot
 * @since 2.1.0
 */
@ConditionalOnClass(ThreadPoolTaskExecutor.class)
@Configuration(proxyBeanMethods = false) // 返回不代理方法返回的实例
@EnableConfigurationProperties(TaskExecutionProperties.class) // 将配置文件参数跟TaskExecutionProperties类绑定
public class TaskExecutionAutoConfiguration {

	/**
	 * Bean name of the application {@link TaskExecutor}.
	 */
	public static final String APPLICATION_TASK_EXECUTOR_BEAN_NAME = "applicationTaskExecutor";

	@Bean
	@ConditionalOnMissingBean
	public TaskExecutorBuilder taskExecutorBuilder(TaskExecutionProperties properties,
			ObjectProvider<TaskExecutorCustomizer> taskExecutorCustomizers,
			ObjectProvider<TaskDecorator> taskDecorator) {
		TaskExecutionProperties.Pool pool = properties.getPool();
		TaskExecutorBuilder builder = new TaskExecutorBuilder();
		builder = builder.queueCapacity(pool.getQueueCapacity());
		builder = builder.corePoolSize(pool.getCoreSize());
		builder = builder.maxPoolSize(pool.getMaxSize());
		builder = builder.allowCoreThreadTimeOut(pool.isAllowCoreThreadTimeout());
		builder = builder.keepAlive(pool.getKeepAlive());
		Shutdown shutdown = properties.getShutdown();
		builder = builder.awaitTermination(shutdown.isAwaitTermination());
		builder = builder.awaitTerminationPeriod(shutdown.getAwaitTerminationPeriod());
		builder = builder.threadNamePrefix(properties.getThreadNamePrefix());
		builder = builder.customizers(taskExecutorCustomizers.orderedStream()::iterator);
		builder = builder.taskDecorator(taskDecorator.getIfUnique());
		return builder;
	}

	@Lazy
	@Bean(name = { APPLICATION_TASK_EXECUTOR_BEAN_NAME,
			AsyncAnnotationBeanPostProcessor.DEFAULT_TASK_EXECUTOR_BEAN_NAME })
	@ConditionalOnMissingBean(Executor.class)
	public ThreadPoolTaskExecutor applicationTaskExecutor(TaskExecutorBuilder builder) {
		return builder.build();
	}

}
```

源码中可以看到当 Spring 容器扫描到 TaskExecutionAutoConfiguration 时会将 配置文件的参数与 TaskExecutionProperties 绑定；

当然 TaskExecutionProperties 也有默认配置：

```java

/**
 * Configuration properties for task execution.
 *
 * @author Stephane Nicoll
 * @author Filip Hrisafov
 * @since 2.1.0
 */
@ConfigurationProperties("spring.task.execution") // 这个就是配置文件对应的前缀了
public class TaskExecutionProperties {

	private final Pool pool = new Pool();

	private final Shutdown shutdown = new Shutdown();

	/**
	 * Prefix to use for the names of newly created threads.
	 */
	private String threadNamePrefix = "task-";


	public static class Pool {
    
    // 队列的容量是 Integer 的最大值
		private int queueCapacity = Integer.MAX_VALUE;

    // 核心数 
		private int coreSize = 8;

    // 最大线程池
		private int maxSize = Integer.MAX_VALUE;

    // 允许核心线程超时
		private boolean allowCoreThreadTimeout = true;

    // 线程的存活时间 60s
		private Duration keepAlive = Duration.ofSeconds(60);

	}

	public static class Shutdown {

    // 执行程序是否应等待计划任务在关机时完成
		private boolean awaitTermination;

    // 执行程序应等待剩余任务完成的最长时间
		private Duration awaitTerminationPeriod;
	}

}
```

因为 @Configuration(proxyBeanMethods = false) 注解 TaskExecutionAutoConfiguration 带 @Bean 注解的方法会返回非代理的实例，

当初始化的时候会按照代码的顺序先执行 `taskExecutorBuilder()` 方法按照配置生成一个 TaskExecutorBuilder 对象放到容器中，

而 `applicationTaskExecutor()` 方法才是真正去构造一个线程池，可以看到方法上有个 @Lazy 注解，说明是懒加载用到了才会去创建。

当使用到的时候就是从容器中获取到一开始创建放到容器中的 TaskExecutorBuilder 对象，调用 `build()` 方法

`build()` 方法对应源码：

```java
	public ThreadPoolTaskExecutor build() {
		return configure(new ThreadPoolTaskExecutor());
	}
```

`configure()` 方法对应源码：

```java
public <T extends ThreadPoolTaskExecutor> T configure(T taskExecutor) {
   PropertyMapper map = PropertyMapper.get().alwaysApplyingWhenNonNull();
   map.from(this.queueCapacity).to(taskExecutor::setQueueCapacity);
   map.from(this.corePoolSize).to(taskExecutor::setCorePoolSize);
   map.from(this.maxPoolSize).to(taskExecutor::setMaxPoolSize);
   map.from(this.keepAlive).asInt(Duration::getSeconds).to(taskExecutor::setKeepAliveSeconds);
   map.from(this.allowCoreThreadTimeOut).to(taskExecutor::setAllowCoreThreadTimeOut);
   map.from(this.awaitTermination).to(taskExecutor::setWaitForTasksToCompleteOnShutdown);
   map.from(this.awaitTerminationPeriod).as(Duration::toMillis).to(taskExecutor::setAwaitTerminationMillis);
   map.from(this.threadNamePrefix).whenHasText().to(taskExecutor::setThreadNamePrefix);
   map.from(this.taskDecorator).to(taskExecutor::setTaskDecorator);
   if (!CollectionUtils.isEmpty(this.customizers)) {
      this.customizers.forEach((customizer) -> customizer.customize(taskExecutor));
   }
   return taskExecutor;
}
```

这里就是去构造 Spring 自带的线程池了，可以看到 Spring 自带的线程池的队列容量和最大队列长度是 Integer 的最大值，这个是非常大的，所以 Spring 自带的线程池不是很推荐直接使用

当然最大的原因是 Spring 的实现的线程池 ThreadPoolTaskExecutor 采用的是拒绝策略

```java
public class ThreadPoolTaskExecutor extends ExecutorConfigurationSupport
    implements AsyncListenableTaskExecutor, SchedulingTaskExecutor {
  
	@Override
	public Future<?> submit(Runnable task) {
		ExecutorService executor = getThreadPoolExecutor();
		try {
			return executor.submit(task);
		}
		catch (RejectedExecutionException ex) {
			throw new TaskRejectedException("Executor [" + executor + "] did not accept task: " + task, ex);
		}
	}

	@Override
	public <T> Future<T> submit(Callable<T> task) {
		ExecutorService executor = getThreadPoolExecutor();
		try {
			return executor.submit(task);
		}
		catch (RejectedExecutionException ex) {
			throw new TaskRejectedException("Executor [" + executor + "] did not accept task: " + task, ex);
		}
	}
}
```

以上个人源码分析看法，所以我们应该自己去定义一个线程池采用 拒绝后由当前现场执行的现场池更符合我们实际开发场景中的需求，毕竟多线程只是为了提高并发和效率