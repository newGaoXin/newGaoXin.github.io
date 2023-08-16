# SpringBoot 异常处理机制

## 一、异常处理自动配置原理

ErrorMvcAutoConfiguration 自动配置异常处理规则：

- - **容器中的组件：类型：DefaultErrorAttributes ->** **id：errorAttributes**

* - - **public class** **DefaultErrorAttributes** **implements** **ErrorAttributes**, **HandlerExceptionResolver**
    - **DefaultErrorAttributes**：定义错误页面中可以包含哪些数据。

* - **容器中的组件：类型：BasicErrorController --> id：basicErrorController（json+白页 适配响应）**

* - - **处理默认** **/error 路径的请求；页面响应** **new** ModelAndView(**"error"**, model)；
    - **容器中有组件 View**->**id 是 error**；（响应默认错误页）
    - 容器中放组件 **BeanNameViewResolver（视图解析器）；按照返回的视图名作为组件的 id 去容器中找 View 对象。**

* - **容器中的组件：类型：DefaultErrorViewResolver -> id：conventionErrorViewResolver**

* - - 如果发生错误，会以 HTTP 的状态码 作为视图页地址（viewName），找到真正的页面
    - error/404、5xx.html

## 二、异常处理步骤流程

1.HTTP 请求会先进入 **DispatcherServlet** 类 **doDispatch** 方法中

```java
// doDispatch 源码
protected void doDispatch(HttpServletRequest request, HttpServletResponse response) throws Exception {
    HttpServletRequest processedRequest = request;
    HandlerExecutionChain mappedHandler = null;
    boolean multipartRequestParsed = false;

    WebAsyncManager asyncManager = WebAsyncUtils.getAsyncManager(request);

    try {
        ModelAndView mv = null;
        Exception dispatchException = null;

        try {
            processedRequest = checkMultipart(request);
            multipartRequestParsed = (processedRequest != request);

            // Determine handler for the current request.
            mappedHandler = getHandler(processedRequest);
            if (mappedHandler == null) {
                noHandlerFound(processedRequest, response);
                return;
            }

            // Determine handler adapter for the current request.
            HandlerAdapter ha = getHandlerAdapter(mappedHandler.getHandler());

            // Process last-modified header, if supported by the handler.
            String method = request.getMethod();
            boolean isGet = "GET".equals(method);
            if (isGet || "HEAD".equals(method)) {
                long lastModified = ha.getLastModified(request, mappedHandler.getHandler());
                if (new ServletWebRequest(request, response).checkNotModified(lastModified) && isGet) {
                    return;
                }
            }

            if (!mappedHandler.applyPreHandle(processedRequest, response)) {
                return;
            }

            // Actually invoke the handler.
            mv = ha.handle(processedRequest, response, mappedHandler.getHandler());

            if (asyncManager.isConcurrentHandlingStarted()) {
                return;
            }

            applyDefaultViewName(processedRequest, mv);
            mappedHandler.applyPostHandle(processedRequest, response, mv);
        }
        catch (Exception ex) {
            dispatchException = ex;
        }
        catch (Throwable err) {
            // As of 4.3, we're processing Errors thrown from handler methods as well,
            // making them available for @ExceptionHandler methods and other scenarios.
            dispatchException = new NestedServletException("Handler dispatch failed", err);
        }
        processDispatchResult(processedRequest, response, mappedHandler, mv, dispatchException);
    }
    catch (Exception ex) {
        triggerAfterCompletion(processedRequest, response, mappedHandler, ex);
    }
    catch (Throwable err) {
        triggerAfterCompletion(processedRequest, response, mappedHandler,
                               new NestedServletException("Handler processing failed", err));
    }
    finally {
        if (asyncManager.isConcurrentHandlingStarted()) {
            // Instead of postHandle and afterCompletion
            if (mappedHandler != null) {
                mappedHandler.applyAfterConcurrentHandlingStarted(processedRequest, response);
            }
        }
        else {
            // Clean up any resources used by a multipart request.
            if (multipartRequestParsed) {
                cleanupMultipart(processedRequest);
            }
        }
    }
}
```

2.在源码中可以看到，在执行目标方法，目标方法运行期间有任何异常都会被 catch、而且标志当前请求结束；并且用 **dispatchException**

3.进入视图解析流程（页面渲染）

processDispatchResult(processedRequest, response, mappedHandler, **mv**, **dispatchException**);

```java
// processDispatchResult 源码
private void processDispatchResult(HttpServletRequest request, HttpServletResponse response,
                                   @Nullable HandlerExecutionChain mappedHandler,
                                   @Nullable ModelAndView mv,
                                   @Nullable Exception exception) throws Exception {

    boolean errorView = false;

    if (exception != null) {
        if (exception instanceof ModelAndViewDefiningException) {
            logger.debug("ModelAndViewDefiningException encountered", exception);
            mv = ((ModelAndViewDefiningException) exception).getModelAndView();
        }
        else {
            Object handler = (mappedHandler != null ? mappedHandler.getHandler() : null);
            mv = processHandlerException(request, response, handler, exception);
            errorView = (mv != null);
        }
    }

    // Did the handler return a view to render?
    if (mv != null && !mv.wasCleared()) {
        render(mv, request, response);
        if (errorView) {
            WebUtils.clearErrorRequestAttributes(request);
        }
    }
    else {
        if (logger.isTraceEnabled()) {
            logger.trace("No view rendering, null ModelAndView returned.");
        }
    }

    if (WebAsyncUtils.getAsyncManager(request).isConcurrentHandlingStarted()) {
        // Concurrent handling started during a forward
        return;
    }

    if (mappedHandler != null) {
        // Exception (if any) is already handled..
        mappedHandler.triggerAfterCompletion(request, response, null);
    }
}
```

4.在 **processDispatchResult** 源码中可以 看到 ，**mv = processHandlerException(request, response, handler, exception)**；处理 handler 发生的异常，处理完成返回 ModelAndView；

```java
// processHandlerException 源码
protected ModelAndView processHandlerException(HttpServletRequest request, HttpServletResponse response,
                                               @Nullable Object handler, Exception ex) throws Exception {

    // Success and error responses may use different content types
    request.removeAttribute(HandlerMapping.PRODUCIBLE_MEDIA_TYPES_ATTRIBUTE);

    // Check registered HandlerExceptionResolvers...
    ModelAndView exMv = null;
    if (this.handlerExceptionResolvers != null) {
        for (HandlerExceptionResolver resolver : this.handlerExceptionResolvers) {
            exMv = resolver.resolveException(request, response, handler, ex);
            if (exMv != null) {
                break;
            }
        }
    }
    if (exMv != null) {
        if (exMv.isEmpty()) {
            request.setAttribute(EXCEPTION_ATTRIBUTE, ex);
            return null;
        }
        // We might still need view name translation for a plain error model...
        if (!exMv.hasView()) {
            String defaultViewName = getDefaultViewName(request);
            if (defaultViewName != null) {
                exMv.setViewName(defaultViewName);
            }
        }
        if (logger.isTraceEnabled()) {
            logger.trace("Using resolved error view: " + exMv, ex);
        }
        else if (logger.isDebugEnabled()) {
            logger.debug("Using resolved error view: " + exMv);
        }
        WebUtils.exposeErrorRequestAttributes(request, ex, getServletName());
        return exMv;
    }

    throw ex;
}
```

4.1 源码中可以看到会去遍历所有的 **HandlerExceptionResolver**

4.2.1 系统默认的 异常解析器

<img src="C:\Users\49270\Desktop\SpringBoot笔记\异常处理笔记截图\handleExceptionResolvers.png" style="zoom:80%;" />

4.2.2

- 1.一开始会执行 **DefaultErrorAttributes**，将异常信息保存在 **request **域中,并且 return null；

```java
public ModelAndView resolveException(HttpServletRequest request, HttpServletResponse response, Object handler,
      Exception ex) {
   storeErrorAttributes(request, ex);
   return null;
}

private void storeErrorAttributes(HttpServletRequest request, Exception ex) {
   request.setAttribute(ERROR_ATTRIBUTE, ex);
}
```

- 2.默认没有任何人能处理异常，所以异常会被抛出

  **如果没有任何人能处理最终底层就会发送 /error 请求。会被底层的 BasicErrorController 处理**

  **解析错误视图；遍历所有的** **ErrorViewResolver 看谁能解析**

  <img src="C:\Users\49270\Desktop\SpringBoot笔记\异常处理笔记截图\errorViewResolvers.png" alt="默认的errorViewResolvers" style="zoom:80%;" />

  **默认的** **DefaultErrorViewResolver ,作用是把响应状态码作为错误页的地址，error/500.html**

  **模板引擎最终响应这个页面** **error/500.html**

## 三、定制错误处理逻辑

1. 自定义错误页

   - error/404.html error/5xx.html；有精确的错误状态码页面就匹配精确，没有就找 4xx.html；如果都没有就触发白页

2. **@ControllerAdvice** + **@ExceptionHandler**：处理全局异常

   - 代码实现

     ```java
     @ControllerAdvice
     public class GlobalExceptionHandler {

         @ExceptionHandler(value = {ArithmeticException.class,NullPointerException.class})
         public String handlerException(){
             // 自定义一系列操作操作...

             // 这边就简单的 return 到 login 页
             return "login";
         }
     }
     ```

   - 根据前面的异常处理步骤流程，进行 debug 走到 4.2.1 可以发现底层是 **ExceptionHandlerExceptionResolver 支持的**

3. @ResponseStatus+自定义异常

   - 代码实现，自定义一个异常类实现 **RuntimeException**

     ```java
     @ResponseStatus(value = HttpStatus.FORBIDDEN,reason = "自己自定义的异常")
     public class MyException extends RuntimeException {

         public MyException(String message) {
             super(message);
         }
     }
     ```

   - 根据前面的异常处理步骤流程，进行 debug 走到 4.2.1 底层是 **ResponseStatusExceptionResolver ，把 responsestatus 注解的信息底层调用** **response.sendError(statusCode, resolvedReason)；tomcat 发送的/error**

4. Spring 底层的异常，如 参数类型转换异常；**DefaultHandlerExceptionResolver 处理框架底层的异常。**

   - response.sendError(HttpServletResponse.**SC_BAD_REQUEST**, ex.getMessage());

     ![](https://cdn.nlark.com/yuque/0/2020/png/1354552/1606114118010-f4aaf5ee-2747-4402-bc82-08321b2490ed.png)

5) 自定义实现 HandlerExceptionResolver 处理异常解析器；可以作为默认的全局异常处理规则

   - 代码实现

     ```java
     @Order(Ordered.HIGHEST_PRECEDENCE) //指定顺序，值越小顺序越高
     @Component
     public class MyHandleException implements HandlerExceptionResolver {
         @Override
         public ModelAndView resolveException(HttpServletRequest request,
                                              HttpServletResponse response,
                                              Object handler,
                                              Exception ex) {

             try {
                 response.sendError(555,"我自定义的异常处理器");
             } catch (IOException e) {
                 e.printStackTrace();
             }
             return new ModelAndView();
         }
     }
     ```

   - 根据前面的异常处理步骤流程，进行 debug 走到 4.2.1 可以发现自定义的处理异常解析器被加载到容器中，并且进行解析

     <img src="C:\Users\49270\Desktop\SpringBoot笔记\异常处理笔记截图\自定义处理异常解析器.png" alt="自定义处理异常解析器" style="zoom: 80%;" />

6. **ErrorViewResolver** 实现自定义处理异常；

   - response.sendError 。error 请求就会转给 controller
   - 你的异常没有任何人能处理。tomcat 底层 response.sendError。error 请求就会转给 controller
   - **basicErrorController 要去的页面地址是** **ErrorViewResolver** ；

-
