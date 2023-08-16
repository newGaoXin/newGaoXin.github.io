# Spring Cloud Stream

## 整合RabbitMq

### 引入依赖

```java
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-stream-rabbit</artifactId>
</dependency>
```



### 3.1 版本之前

#### 1.配置文件



### 3.1 版本之后

#### 1.配置文件

##### Binder

Binder 中配置了对接外部消息中间件所需要的连接信息。如果你的程序中只使用了单一的中间件，比如只接入了 RabbitMQ，那么你可以直接在 spring.rabbitmq 节点下配置连接串，不需要特别指定 binders 配置。

```yaml
spring:
  cloud:
    stream:
      # 如果你项目里只对接一个中间件，那么不用定义binders
      # 当系统要定义多个不同消息中间件的时候，使用binders定义
      binders:
        my-rabbit:
          type: rabbit # 消息中间件类型
          environment: # 连接信息
            spring:
              rabbitmq:
                host: localhost
                port: 5672
                username: guest
                password: guest
```

##### Bindings

这个节点保存了生产者、消费者、binder 和 RabbitMQ 四方的关联关系。

```yaml
spring:
  cloud:
    stream:
      bindings:
        # 添加coupon - Producer
        addCoupon-out-0:
          destination: request-coupon-topic
          content-type: application/json
          binder: my-rabbit
        # 添加coupon - Consumer
        addCoupon-in-0:
          destination: request-coupon-topic
          content-type: application/json
          # 消费组，同一个组内只能被消费一次
          group: add-coupon-group
          binder: my-rabbit
        # 删除coupon - Producer
        deleteCoupon-out-0:
          destination: delete-coupon-topic
          content-type: text/plain
          binder: my-rabbit
        # 删除coupon - Consumer
        deleteCoupon-in-0:
          destination: delete-coupon-topic
          content-type: text/plain
          group: delete-coupon-group
          binder: my-rabbit
      function:
        definition: addCoupon;deleteCoupon
```



我们以 addCoupon 为例，你会看到我定义了 addCoupon-out-0 和 addCoupon-in-0 这两个节点，节点名称中的 out 代表当前配置的是一个生产者，而 in 则代表这是一个消费者，这便是 spring-function 中约定的命名关系：

Input 信道（消费者）：< functionName > - in - < index >；

Output 信道（生产者）：< functionName > - out - < index >。

在命名规则的最后还有一个 index，它是 input 和 output 的序列，如果同一个 function name 只有一个 output 和一个 input，那么这个 index 永远都是 0。而如果你需要为一个 function 添加多个 input 和 output，就需要使用 index 变量来区分每个生产者消费者了。可以参考文稿中的 [官方社区文档](https://docs.spring.io/spring-cloud-stream/docs/3.1.0/reference/html/spring-cloud-stream.html#_functions_with_multiple_input_and_output_arguments)。



#### 2.生产者

生产者只做一件事，就是生产一个消息事件，并将这个事件发送到 RabbitMQ。添加了 sendCoupon 和 deleteCoupon 这两个生产者方法，分别对应了领取优惠券和删除优惠券。在这两个方法内，我使用了 StreamBridge 这个 Stream 的原生组件，将信息发送给 RabbitMQ。

```java
@Service
@Slf4j
public class CouponProducer {

    @Autowired
    private StreamBridge streamBridge;

    public void sendCoupon(RequestCoupon coupon) {
        log.info("sent: {}", coupon);
        streamBridge.send(EventConstant.ADD_COUPON_EVENT, coupon);
    }

    public void deleteCoupon(Long userId, Long couponId) {
        log.info("sent delete coupon event: userId={}, couponId={}", userId, couponId);
        streamBridge.send(EventConstant.DELETE_COUPON_EVENT, userId + "," + couponId);
    }

}
```



#### 3.消费者

在这段代码中，有一个“约定大于配置”的规矩你一定要遵守，那就是不要乱起方法名。我这里定义的 addCoupon、deleteCoupon 两个方法名是有来头的，你要确保消费者方法的名称和配置文件中所定义的 Function Name 以及 Binding Name 保持一致，这是 function event 的一条潜规则（其实是因为@Bean注解默认使用方法名称作为bean的名称）。因为在默认情况下，框架会使用消费者方法的 method name 作为当前消费者的标识，如果消费者标识和配置文件中的名称不一致，那么 Spring 应用就不知道该把当前的消费者绑定到哪一个 Stream 信道上去。

```java
@Slf4j
@Service
public class CouponConsumer {

    @Autowired
    private CouponCustomerService customerService;

    @Bean
    public Consumer<RequestCoupon> addCoupon() {
        return request -> {
            log.info("received: {}", request);
            customerService.requestCoupon(request);
        };
    }

    @Bean
    public Consumer<String> deleteCoupon() {
        return request -> {
            log.info("received: {}", request);
            List<Long> params = Arrays.stream(request.split(","))
                    .map(Long::valueOf)
                    .collect(Collectors.toList());
            customerService.deleteCoupon(params.get(0), params.get(1));
        };
    }

}
```

##### 消息重试

消息重试是一种简单高效的异常恢复手段，当 Consumer 端抛出异常的时候，Stream 会自动执行 2 次重试。重试次数是由 ConsumerProperties 类中的 maxAttempts 参数指定的，它设置了一个消息最多可以被 Consumer 执行几次。

```java
private int maxAttempts = 3; // 默认三次
```

在 application.yml 文件中，你可以在 spring.cloud.stream.bindings 节点下添加一个 consumer 节点，以 addCoupon-in-0 为例，我通过 consumer 节点指定了消息消费次数、重试间隔还有异常重试规则。

```yaml
spring:
  cloud:
    stream:
      bindings:
        addCoupon-in-0:
          destination: request-coupon-topic
          content-type: application/json
          # 消费组，同一个组内只能被消费一次
          group: add-coupon-group
          binder: my-rabbit
          consumer:
            # 如果最大尝试次数为1，即不重试
            # 默认是做3次尝试
            max-attempts: 5
            # 两次重试之间的初始间隔
            backOffInitialInterval: 2000
            # 重试最大间隔
            backOffMaxInterval: 10000
            # 每次重试后，间隔时间乘以的系数
            backOffMultiplier: 2
            # 如果某个异常你不想重试，写在这里
            retryableExceptions:
              java.lang.IllegalArgumentException: false
```

以代码中的参数为例，首次重试会发生在异常抛出 2s 以后，再过 4s 发生第二次重试（即 2s 乘以 backOffMultiplier 时间系数 2），以此类推，再过 8s 发生第三次重试。但第四次重试和第三次之间的间隔并不是 8s*2=16s，因为我们设置了重试的最大间隔时间为 10s，所以最后一次重试会在上一次重试后的第 10s 发起。

如果你想为某种特定类型的异常关闭重试功能，你还可以将这些异常类添加到 retryableExceptions 节点下，并指定它的重试开关为 false。比如我这里设置了针对 java.lang.IllegalArgumentException 类型的异常一律不发起重试，Consumer 消费失败时这个异常会被直接抛到最外层。

除了本地重试以外，你还可以把这个失败的消息丢回到原始队列中，做一个 requeue 的操作。在 requeue 模式下，这个消息会以类似“roundrobin”的方式被集群中的各个 Consumer 消费，你可以参考我下面的配置，我为指定 Consumer 添加了 requeue 的功能。（如果你打算使用 requeue 作为重试条件，把 max-attempts 设置为 1 吧）

##### 异常降级方法

我通过 spring-integration 的注解 @ServiceActivator 做了一个桥接，将指定 Channel 的异常错误转到我的本地方法里。

```java
@ServiceActivator(inputChannel = "request-coupon-topic.add-coupon-group.errors")
public void requestCouponFallback(ErrorMessage errorMessage) throws Exception {
    log.info("consumer error: {}", errorMessage);
    // 实现自己的逻辑
}
```

inputChannel 属性的值是由三部分构成的，它的格式是：..errors。我通过 topic 和 group 指定了当前的 inputChannel 是来自于哪个消息队列和分组。

降级逻辑处理完之后，这个原始的 Message 怎么办呢？如果你想要保留这条出错的 Message，那你可以选择将它发送到另一个 Queue 里。待技术团队将异常情况排除之后，你可以选择在未来的某一个时刻将 Queue 里的消息重新丢回到正常的队列中，让消费者重新处理。当然了，你也可以声明一个消费者，专门用来处理这个 Queue 里的消息。



##### 配置死信队列

在配置死信队列之前，先安装两个 RabbitMQ 的插件，分别是 rabbitmq_shovel 和 rabbitmq_shovel_management。这两个插件是用来做消息移动的，让我们可以将死信队列的消息移动到其它正常队列重新消费。

```shell
rabbitmq-plugins enable rabbitmq_shovel
rabbitmq-plugins enable rabbitmq_shovel_management
```

配置文件

```yaml
spring:
  cloud:
    stream:
      rabbit:
        bindings:
          deleteCoupon-in-0:
            consumer:
              auto-bind-dlq: true
```





### 信道和 RabbitMQ 里定义的消息队列之间的关系

信道和 RabbitMQ 的绑定关系是通过 binder 属性指定的。如果当前配置文件的上下文中只有一个消息中间件（比如使用默认的 MQ），你并不需要声明 binder 属性。但如果你配置了多个 binder，那就需要为每个信道声明对应的 binder 是谁。addCoupon-out-0 对应的 binder 名称是 my-rabbit，这个 binder 就是我刚才在 spring.cloud.stream.binders 里声明的配置。通过这种方式，生产者消费者信道到消息中间件（binder）的联系就建立起来了。

信道和消息队列的关系是通过 destination 属性指定的。以 addCoupon 为例，我在 addCoupon-out-0 生产者配置项中指定了 destination=request-coupon-topic，意思是将消息发送到名为 request-coupon-topic 的 Topic 中。我又在 addCoupon-in-0 消费者里添加了同样的配置，意思是让当前消费者从 request-coupon-topic 消费新的消息。