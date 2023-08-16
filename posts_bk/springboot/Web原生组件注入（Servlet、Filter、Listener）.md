# Web 原生组件注入（Servlet、Filter、Listener）

## 一、使用 Servlet API

使用 @WebServlet(urlPatterns = **"/my"**) 并继承 **HttpServlet**：效果：直接响应，**没有经过 Spring 的拦截器？**

使用 @WebFilter(urlPatterns={**"/css/\*"**,**"/images/\*"**}) 并实现 **Filter**

使用 @WebListener 并实现 **ServletContextListener**

最后需要在启动类上加上注解 @ServletComponentScan(basePackages = **"指定包路径"**) :指定原生 Servlet 组件都放在那里

推荐可以这种方式；

## 二、使用 RegistrationBean

**ServletRegistrationBean** 、**FilterRegistrationBean** 、**ServletListenerRegistrationBean**

```java
@Configuration
public class MyRegistConfig {

    @Bean
    public ServletRegistrationBean myServlet(){
        MyServlet myServlet = new MyServlet();

        return new ServletRegistrationBean(myServlet,"/my","/my02");
    }


    @Bean
    public FilterRegistrationBean myFilter(){

        MyFilter myFilter = new MyFilter();
//        return new FilterRegistrationBean(myFilter,myServlet());
        FilterRegistrationBean filterRegistrationBean = new FilterRegistrationBean(myFilter);
        filterRegistrationBean.setUrlPatterns(Arrays.asList("/my","/css/*"));
        return filterRegistrationBean;
    }

    @Bean
    public ServletListenerRegistrationBean myListener(){
        MySwervletContextListener mySwervletContextListener = new MySwervletContextListener();
        return new ServletListenerRegistrationBean(mySwervletContextListener);
    }
}
```

## 三、扩展：DispatchServlet 如何注册进来

- 容器中自动配置了 DispatcherServlet 属性绑定到 WebMvcProperties；对应的配置文件配置项是 **spring.mvc。**

- **通过** **ServletRegistrationBean**<DispatcherServlet> 把 DispatcherServlet 配置进来。

- 默认映射的是 / 路径。

<img src="https://cdn.nlark.com/yuque/0/2020/png/1354552/1606284869220-8b63d54b-39c4-40f6-b226-f5f095ef9304.png?x-oss-process=image%2Fwatermark%2Ctype_d3F5LW1pY3JvaGVp%2Csize_14%2Ctext_YXRndWlndS5jb20g5bCa56GF6LC3%2Ccolor_FFFFFF%2Cshadow_50%2Ct_80%2Cg_se%2Cx_10%2Cy_10" style="zoom:80%;" />

Tomcat-Servlet；

多个 Servlet 都能处理到同一层路径，精确优选原则

例如：

A Servelt 路径： /my/

B Servelt 路径： /my/1

那么当用户请求 /my/1 时，就会去找 B Servlet
