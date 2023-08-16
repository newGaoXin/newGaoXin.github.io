# SpringBoot HTTP 请求源码流程

笔记基于 SpringBoot 2.3.4.RELEASE 版本

平常工作中跟前端对接的时候，对于 HTTP 请求的原理就很疑惑，SpringMVC 在拿到请求参数后怎么去赋值，并且如何又返回了 JSON 数据

带着这个疑惑

看了 尚硅谷 雷丰阳老师的 2021 版 SpringBoot2 零基础入门 springboot 全套完整版（spring boot2）干货满满

下面就初略记录下我学习的笔记

## HttpServlet

最早的 SpringMVC 的时候我们都是 HttpServlet 类是所有 HTTP 请求的处理类的父类

用 IDEA 查看它的继承关系，可以在 HttpServlet 有这些子类

![HttpServlet继承关系图](C:\Users\49270\Desktop\SpringBoot笔记\HttpServlet继承关系图.png)

最后的一个子类是 DispatcherServlet

## 获取处理器、处理器配饰器

在 DispatcherServlet 类中实现了 HttpServlet 的 doService( ) 方法

```java
protected void doService(HttpServletRequest request, HttpServletResponse response) throws Exception {

    // 942行
    try {
        doDispatch(request, response);
    }
    finally {
        if (!WebAsyncUtils.getAsyncManager(request).isConcurrentHandlingStarted()) {
            // Restore the original attribute snapshot, in case of an include.
            if (attributesSnapshot != null) {
                restoreAttributesAfterInclude(request, attributesSnapshot);
            }
        }
    }

}
```

doService( ) 方法最近进入到 doDispatch( )

在 doDIspatch( ) 方法中 有几行关键的代码

```java
protected void doDispatch(HttpServletRequest request, HttpServletResponse response) throws Exception {

    // 这部分代码让我想到了当初学SpringMVC时的执行流程
    // 获取处理器 -> 获取对应的配饰器处理器

    // ①
    // Determine handler for the current request.
    mappedHandler = getHandler(processedRequest);

    // ②
    // Determine handler adapter for the current request.
    HandlerAdapter ha = getHandlerAdapter(mappedHandler.getHandler());

    // ③
    // Actually invoke the handler.
    mv = ha.handle(processedRequest, response, mappedHandler.getHandler());
}
```

第一步：先去获取处理器

第二步：获取对应的处理器配饰器

第三步：使用对应的处理器配饰器去执行处理器

记录笔记是 使用的是 POST 请求进行断点 调式的 Controller 层中接受的方法参数中没有加任何注解

所以 获取到的配饰器 是 AbstractHandlerMethodAdapter

（其实大部分情况我们拿到的都是这个配饰器，除非使用了注解比较特殊的情况下）

## 执行处理器配饰器

那么会进入 AbstractHandlerMethodAdapter 的 handle( ) 方法

```java
/**
	* This implementation expects the handler to be an {@link HandlerMethod}.
	 */
@Override
@Nullable
public final ModelAndView handle(HttpServletRequest request, HttpServletResponse response, Object handler)
    throws Exception {

    return handleInternal(request, response, (HandlerMethod) handler);

}
```

我们可以继续执行下去

这时候进入到 RequestMappingHandlerAdapter 类的 handleInternal( ) 方法中

```java
@Override
protected ModelAndView handleInternal(HttpServletRequest request,
		HttpServletResponse response, HandlerMethod handlerMethod) throws Exception {

	// 关键代码
    // No synchronization on session demanded at all...
    mav = invokeHandlerMethod(request, response, handlerMethod);

}
```

在这里调用 invokeHandlerMethod 方法去执行处理器的方法，我们进入方法中

```java
@Nullable
protected ModelAndView invokeHandlerMethod(HttpServletRequest request,
		HttpServletResponse response, HandlerMethod handlerMethod) throws Exception {

    // 这里做了一系列的动作我们可以忽略
    // 关键代码
    invocableMethod.invokeAndHandle(webRequest, mavContainer);

}
```

继续进入方法中

会来到 ServletInvocableHandlerMethod 类 invokeAndHandle( ) 方法中

```java
public void invokeAndHandle(ServletWebRequest webRequest, ModelAndViewContainer mavContainer,
		Object... providedArgs) throws Exception {
    // ...

	// 关键代码  ①
	Object returnValue = invokeForRequest(webRequest, mavContainer, providedArgs);

    // ...

    // 关键代码  ②
    try {
        this.returnValueHandlers.handleReturnValue(
            returnValue, getReturnValueType(returnValue), mavContainer, webRequest);
    }
}
```

关键代码 ①：invokeForRequest( ) 方法执行之后会拿到返回值

关键代码 ②：this.returnValueHandlers.handleReturnValue( ) 是处理返回值

那么我们先进入 invokeForRequest( ) 方法中

### 获取请求参数

来到了 InvocableHandlerMethod 类 invokeForRequest( ) 方法

```java
@Nullable
public Object invokeForRequest(NativeWebRequest request, @Nullable ModelAndViewContainer mavContainer,
                               Object... providedArgs) throws Exception {

    // 这里是去获取 方法参数值
    Object[] args = getMethodArgumentValues(request, mavContainer, providedArgs);
    if (logger.isTraceEnabled()) {
        logger.trace("Arguments: " + Arrays.toString(args));
    }

    // 带着参数去执行 http请求的具体方法
    // 这里可以打个断点在Controller方法中 看看是不是先进入具体方法再返回
    return doInvoke(args);
}

```

我们先进入 getMethodArgumentValues( ) 方法中

```java
protected Object[] getMethodArgumentValues(NativeWebRequest request,
		@Nullable ModelAndViewContainer 	mavContainer,Object... providedArgs) throws Exception {

    // 这里取获取参数
    MethodParameter[] parameters = getMethodParameters();
    if (ObjectUtils.isEmpty(parameters)) {
        // 参数为空那么直接return
        return EMPTY_ARGS;
    }

    Object[] args = new Object[parameters.length];
    for (int i = 0; i < parameters.length; i++) {
        MethodParameter parameter = parameters[i];
        parameter.initParameterNameDiscovery(this.parameterNameDiscoverer);
        args[i] = findProvidedArgument(parameter, providedArgs);
        if (args[i] != null) {
            continue;
        }
        // 获取支持当前参数的解析器
        if (!this.resolvers.supportsParameter(parameter)) {
            throw new IllegalStateException(formatArgumentError(parameter, "No suitable resolver"));
        }
        try {
            // 解析器执行解析方法 拿到参数
            args[i] = this.resolvers.resolveArgument(parameter, mavContainer, request, this.dataBinderFactory);
        }
        catch (Exception ex) {
            // Leave stack trace for later, exception may actually be resolved and handled...
            if (logger.isDebugEnabled()) {
                String exMsg = ex.getMessage();
                if (exMsg != null && !exMsg.contains(parameter.getExecutable().toGenericString())) {
                    logger.debug(formatArgumentError(parameter, exMsg));
                }
            }
            throw ex;
        }
    }
    return args;
}
```

可以从源码中，看到执行流程是

第一步：拿到请求的 Controller 方法参数列表

第二步：遍历参数获取参数对应的解析器

第三步：执行解析器的解析参数方法

### 处理返回值

那么我们那么方法执行下去，进入 Controller 中执行完成之后，拿到所有返回值后，返回到 ServletInvocableHandlerMethod 类 invokeAndHandle( ) 方法中

```java
public void invokeAndHandle(ServletWebRequest webRequest, ModelAndViewContainer mavContainer,
		Object... providedArgs) throws Exception {
    // ...

	// 关键代码  ①
	Object returnValue = invokeForRequest(webRequest, mavContainer, providedArgs);

    // ...

    // 关键代码  ②
    try {
        this.returnValueHandlers.handleReturnValue(
            returnValue, getReturnValueType(returnValue), mavContainer, webRequest);
    }
}
```

断点进入 this.returnValueHandlers.handleReturnValue( ) 方法中

来到 HandlerMethodReturnValueHandlerComposite 类 handleReturnValue( ) 方法

```java
@Override
public void handleReturnValue(@Nullable Object returnValue, MethodParameter returnType,
		ModelAndViewContainer mavContainer, NativeWebRequest webRequest) throws Exception {

    // 关键代码 ① 拿到对应的 处理方法返回值处理器
    HandlerMethodReturnValueHandler handler = selectHandler(returnValue, returnType);
    if (handler == null) {
        throw new IllegalArgumentException("Unknown return value type: " + returnType.getParameterType().getName());
    }
    // 关键代码 ② 执行对应的处理器方法进行处理
    handler.handleReturnValue(returnValue, returnType, mavContainer, webRequest);
}
```

在方法中，我们先拿到对应的处理方法返回值处理器，再执行处理器的方法

断点进去 handler.handleReturnValue(returnValue, returnType, mavContainer, webRequest) 方法中

来到 RequestResponseBodyMethodProcessor 类 handleReturnValue( ) 方法

```java
@Override
public void handleReturnValue(@Nullable Object returnValue, MethodParameter returnType,
		ModelAndViewContainer mavContainer, NativeWebRequest webRequest)
    throws IOException, HttpMediaTypeNotAcceptableException, HttpMessageNotWritableException {

    mavContainer.setRequestHandled(true);
    ServletServerHttpRequest inputMessage = createInputMessage(webRequest);
    ServletServerHttpResponse outputMessage = createOutputMessage(webRequest);

    // 这里去执行消息转行器写出
    // Try even with null return value. ResponseBodyAdvice could get involved.
    writeWithMessageConverters(returnValue, returnType, inputMessage, outputMessage);
}
```

断点进入 writeWithMessageConverters(returnValue, returnType, inputMessage, outputMessage) 方法中

来到 AbstractMessageConverterMethodProcessor 类 writeWithMessageConverters( ) 方法

```java
@SuppressWarnings({"rawtypes", "unchecked"})
protected <T> void writeWithMessageConverters(@Nullable T value, MethodParameter returnType,
	ServletServerHttpRequest inputMessage, ServletServerHttpResponse outputMessage) throws IOException, HttpMediaTypeNotAcceptableException, HttpMessageNotWritableException {

    // ...

    // 关键代码块 ①
    // 媒体类型
    MediaType selectedMediaType = null;
    MediaType contentType = outputMessage.getHeaders().getContentType();
    boolean isContentTypePreset = contentType != null && contentType.isConcrete();
    if (isContentTypePreset) {
        // 这里面一般不会进来 我也不知道什么情况进行 忽略 基本 isContentTypePreset 都是false
        // by 2026-06-05
        if (logger.isDebugEnabled()) {
            logger.debug("Found 'Content-Type:" + contentType + "' in response");
        }
        selectedMediaType = contentType;
    }
    else {
        HttpServletRequest request = inputMessage.getServletRequest();
        // 这里拿到客户端支持的协商媒体类型 也就是请求头中 Accept 中的参数
        List<MediaType> acceptableTypes = getAcceptableMediaTypes(request);
        // 这里拿到服务端支持的协商媒体类型
        List<MediaType> producibleTypes = getProducibleMediaTypes(request, valueType, targetType);

        if (body != null && producibleTypes.isEmpty()) {
            throw new HttpMessageNotWritableException(
                "No converter found for return value of type: " + valueType);
        }
        List<MediaType> mediaTypesToUse = new ArrayList<>();
        // 在双重增强 for循环 中确定 协商媒体类型
        for (MediaType requestedType : acceptableTypes) {
            for (MediaType producibleType : producibleTypes) {
                if (requestedType.isCompatibleWith(producibleType)) {
                    mediaTypesToUse.add(getMostSpecificMediaType(requestedType, producibleType));
                }
            }
        }
        if (mediaTypesToUse.isEmpty()) {
            if (body != null) {
                throw new HttpMediaTypeNotAcceptableException(producibleTypes);
            }
            if (logger.isDebugEnabled()) {
                logger.debug("No match for " + acceptableTypes + ", supported: " + producibleTypes);
            }
            return;
        }

        // 排序我猜测是根据权重吧，客户端请求的时候会设置权重值
        MediaType.sortBySpecificityAndQuality(mediaTypesToUse);

        for (MediaType mediaType : mediaTypesToUse) {
            if (mediaType.isConcrete()) {
                selectedMediaType = mediaType;
                break;
            }
            else if (mediaType.isPresentIn(ALL_APPLICATION_MEDIA_TYPES)) {
                selectedMediaType = MediaType.APPLICATION_OCTET_STREAM;
                break;
            }
        }

        if (logger.isDebugEnabled()) {
            logger.debug("Using '" + selectedMediaType + "', given " +
                         acceptableTypes + " and supported " + producibleTypes);
        }
    }


    // 关键代码块 ②
    // 在上面 我们拿到了 selectedMediaType
    if (selectedMediaType != null) {
        selectedMediaType = selectedMediaType.removeQualityValue();
        for (HttpMessageConverter<?> converter : this.messageConverters) {
            GenericHttpMessageConverter genericConverter =
                (converter instanceof GenericHttpMessageConverter
                 ? (GenericHttpMessageConverter<?>) converter : null);
            // 这里调用 消息转换器 canWrite() 方法 判断支不支持写
            // 消息转换器有很多种类型 其中就有 支持JSON的，这里就解释了为什么可以转换成JSON
			if (genericConverter != null ? ((GenericHttpMessageConverter) converter).canWrite(targetType, valueType, selectedMediaType) : converter.canWrite(valueType, selectedMediaType)) {
                body = getAdvice()
                    .beforeBodyWrite(body,
                                     returnType,
                                     selectedMediaType,
                                     (Class<? extends HttpMessageConverter<?>>) converter.getClass(),
									 	inputMessage, outputMessage);

                if (body != null) {
                    Object theBody = body;
                    LogFormatUtils
                        .traceDebug(logger,
                                    traceOn -> "Writing [" + LogFormatUtils.
                                    							formatValue(theBody, !traceOn) + "]");

                    addContentDispositionHeader(inputMessage, outputMessage);
                    if (genericConverter != null) {
                        genericConverter.write(body, targetType, selectedMediaType, outputMessage);
                    }
                    else {
                        // 这里去执行 消息转换器对应的写方法
                        ((HttpMessageConverter) converter).write(body, selectedMediaType, outputMessage);
                    }
                }
                else {
                    if (logger.isDebugEnabled()) {
                        logger.debug("Nothing to write: null body");
                    }
                }
                return;
            }
        }
    }

}
```

这部份代码有点乱，看源码效果会更好，更清晰

可以分为两部分

1.协商

1.1 获取请求的客户端 Headers 中 Accept 支持的类型

1.2 获取服务端支持的 Accept 类型

1.3 双重增强 for 循环确定 Accept 类型

2.消息转换

1.增强 for 循环 遍历找到支持，要返回的 Accept 类型的消息转换器

2.执行指定的消息转换器转换 write( ) 方法

注：我们注：这里我们可以实现 WebMvcConfigurer#addFormatters 方法增加自定的转换器

eg：

```java
// 增加自定义消息转换器
@Override
public void extendMessageConverters(List<HttpMessageConverter<?>> converters) {
    converters.add(new MyConverter());
}

// 实现 HttpMessageConverter 自定义消息转换器
public class MyConverter implements HttpMessageConverter<User> {

    @Override
    public boolean canRead(Class<?> clazz, MediaType mediaType) {
        return false;
    }

    @Override
    public boolean canWrite(Class<?> clazz, MediaType mediaType) {
        return clazz.isAssignableFrom(User.class);
    }

    @Override
    public List<MediaType> getSupportedMediaTypes() {
        return MediaType.parseMediaTypes("application/abc");
    }

    @Override
    public User read(Class<? extends User> clazz, HttpInputMessage inputMessage) throws IOException, HttpMessageNotReadableException {
        return null;
    }

    @Override
    public void write(User user, MediaType contentType, HttpOutputMessage outputMessage) throws IOException, HttpMessageNotWritableException {
        String value = user.getName() + ";" + user.getAge();
        OutputStream body = outputMessage.getBody();
        body.write(value.getBytes());
    }
}
```

## 最后最后...

这里只是对 HTTP 请求的流程进行一个梳理，只关注了大致的流程，没有关注具体的实现，是怕太具体对于现在的我来说不利于理解

收获除了知道了原理之外，Spring 的架构工程师，代码书写的规范，方法名基本上见名知其义
