# SpringCloud 2020.x.x版本使用nacos坑

在学习项目的时候，我用的Spring Cloud 版本是

```xml
<spring-cloud.version>2020.0.4</spring-cloud.version>
```

Spring Cloud Alibaba 的依赖管理版本是：

```xml
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-alibaba-dependencies</artifactId>
    <version>2.2.6.RELEASE</version>
    <type>pom</type>
    <scope>import</scope>
</dependency>
```



在使用 nacos 做为远程配置中心的时候，引入了maven坐标

```xml
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-nacos-config</artifactId>
</dependency>
```

## 坑一：配置文件优先级不够

我先是将 nacos 远程配置中心的配置写在了 application.yaml 文件中

后面百度才知道要写在 bootstrap.properties 中才生效 ，但是其实我们看日志输出

```java
2021-11-05 22:48:03.248  WARN 18284 --- [           main] c.n.c.sources.URLConfigurationSource     : No URLs will be polled as dynamic configuration sources.
2021-11-05 22:48:03.248  INFO 18284 --- [           main] c.n.c.sources.URLConfigurationSource     : To enable URLs as dynamic configuration sources, define System property archaius.configurationSource.additionalUrls or make config.properties available on classpath.
```

警告说 No URLs will be polled as dynamic configuration sources 大概就是 **不能将任何URL轮询动态配置源**

下面 

**To enable URLs as dynamic configuration sources, define System property archaius.configurationSource.additionalUrls or make config.properties available on classpath.**

这句告诉我们如果要使用 url 动态配置，那么我们要定义一个系统属性 **archaius.configurationSource.additionalUrls** 或者 **config.properties**

因为对源码不太了解，这里猜测是配置优先级不够（后面深入了解源码了再回头）



## 坑二：配置优先级未生效

之后我将，配置移入到了 bootstrap.properties 中

```properties
spring.application.name=gulimall-member
spring.cloud.nacos.discovery.server-addr=127.0.0.1:8848
spring.cloud.nacos.config.server-addr=127.0.0.1:8848
spring.cloud.nacos.config.namespace=1f75207b-b775-49ca-9873-8bd19a1cdfcf
spring.cloud.nacos.config.group=dev
spring.cloud.nacos.config.extension-configs[0].data-id=base.yaml
spring.cloud.nacos.config.extension-configs[0].group=dev
spring.cloud.nacos.config.extension-configs[0].refresh=true
```

百度查阅后，发现 Spring Cloud 2020.x.x 版本 ，官方重构了bootstrap引导配置的加载方式

需要引入

```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-bootstrap</artifactId>
</dependency>
```

重新启动项目，成功读取到了远程配置！