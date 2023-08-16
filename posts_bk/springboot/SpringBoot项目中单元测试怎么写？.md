# SpringBoot项目中单元测试怎么写？

长期以来我写单测的方式就是写完一个方法，对这个方法进行测试，然后一旦项目中使用到了 Spring 容器每次测试一个方法，需要等待容器初始化漫长的过程，方法中如果涉及到对持久层的操作，不可避免的有脏数据写入数据库，好奇大厂单测的解决方案是什么？

不懂就百度，看到网上分享出来的解决方案就是，Mockito（构造数据） + H2（内存数据库进行增删改查） 来进行单元测试

## 一、Mockito

### 1. 是什么？

Mockito 是一种 Java Mock 框架，他主要就是用来做 Mock 测试的，它可以模拟任何 Spring 管理的 Bean、模拟方法的返回值、模拟抛出异常等等，同时也会记录调用这些模拟方法的参数、调用顺序，从而可以校验出这个 Mock 对象是否有被正确的顺序调用，以及按照期望的参数被调用。

目的：通过使用 Mock 的方式，忽略底层的其他逻辑，单纯校验自己所负责的层次的逻辑是否合理

### 2. 怎么用？

#### 2.1 快速入门

在SpringBoot 项目中 maven 坐标引入 spring-boot-start-test

```java
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-test</artifactId>
  <scope>test</scope>
</dependency>
```

现在有一个 `HelloWorldService#sayHello()` 方法需要测试

```java
public class HelloWorldService {

    public String sayHello(String name){
        return name + ",HelloWorld";
    }
}
```

测试类

```java
public class HelloWorldServiceTest {

    @Mock
    private HelloWorldService helloWorldService;
    
    @Test
    public void sayHelloTest(){
        // init
        MockitoAnnotations.openMocks(this);
        // quickTest
        // when 则当调用 helloWorldService#sayHello() 方法
        // Mockito.any() 表示任何参数
        // thenReturn() 表示方法的入参就是调用之后的结果
        Mockito.when(helloWorldService.sayHello(Mockito.any())).thenReturn("Hello World!");
        // test
        String hello = helloWorldService.sayHello("111");
        // Assertions 断言 assertEquals(para1，para2) para1：期望值， para2：当前值
        Assertions.assertEquals("Hello World!",hello);
    }
}
```

Tip: SpringBoot 版本小于 2.x 的需要在项目中 Test类上增加注解 @RunWith(class = MockitoJUnitRunner.class) 启动 Mockito 的上下文

#### 2.2 更多使用推荐看文档：

[hehonghui/mockito-doc-zh: Mockito框架中文文档 (github.com)](https://github.com/hehonghui/mockito-doc-zh#0)

#### 

## 三、H2 进行持久层单元测试

Mockito 基本可以通过打桩构造数据测试业务流程，但是持久层的 SQL 语句如果不进行测试还是会有出错的可能，利用 H2 内存数据库就可以进行 SQL 测试

### 1. 是什么

**H2**是一个Java编写的关系型数据库，它可以被嵌入Java应用程序中使用，或者作为一个单独的数据库服务器运行（百度copy来的）

它的 SQL 语句跟 MySQL 差不多，我们可以在持久层使用 H2 数据库进行测试



### 2.怎么用？

#### 2.1 快速入门

案例：在项目当中写了一个 `SysDeptDao#selectDeptById()` 方法我们需要对他进行测试

Dao（持久层）：

```java
public interface SysDeptDao
{
    /**
     * 根据部门ID查询信息
     * 
     * @param deptId 部门ID
     * @return 部门信息
     */
    public SysDept selectDeptById(Long deptId);
}
```

Service（业务层）:

```java
public class SysDeptServiceImpl {
  
    /**
       * 根据部门ID查询信息
       * 
       * @param deptId 部门ID
       * @return 部门信息
       */
    @Override
    public SysDept selectDeptById(Long deptId)
    {
      return deptMapper.selectDeptById(deptId);
    }
}
```

测试类（Test）

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
class SysDeptServiceImplTest {

    @InjectMocks	// 
    @Spy // 调用真实方法
    private SysDeptServiceImpl deptService;
    @SpyBean
    private SysDeptMapper sysDeptMapper;

    @BeforeEach
    void setUp() {

        MockitoAnnotations.openMocks(this);
    }

    @Test
    void selectDeptById() {
        SysDept sysDept = deptService.selectDeptById(100L);
        Assertions.assertEquals("若依科技1",sysDept.getDeptName());
    }
}
```



