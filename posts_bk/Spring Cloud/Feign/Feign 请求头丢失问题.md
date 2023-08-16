# Feign 请求头丢失问题

配置类中添加 RequestInterceptor 拦截器

```java
@Configuration
public class FeignConfig {

    /**
     * 调用feign请求，请求头丢失问题
     *
     * @return
     */
    @Bean
    public RequestInterceptor requestInterceptor() {
        return new RequestInterceptor() {

            @Override
            public void apply(RequestTemplate requestTemplate) {
                // 获取老请求的请求头内容
                ServletRequestAttributes requestAttributes = (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
                HttpServletRequest request = requestAttributes.getRequest();
                String xxx = request.getHeader("xxx");
                // 将老请求需要传递的请求头内容设置到feign请求中
                requestTemplate.header("xxx", xxx);
            }
        };
    }
}
```

