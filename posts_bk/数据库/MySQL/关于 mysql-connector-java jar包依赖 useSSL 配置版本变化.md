# 关于 mysql-connector-java jar包依赖 useSSL 配置版本变化

mysql-connector-java  jar包依赖，所有的连接配置参数都在 `ConnectionPropertiesImpl` 类的无参构造方法中，初始化时设置默认值。

```java
 public ConnectionPropertiesImpl() {
   
   // 省略...
           this.useSSL = new BooleanConnectionProperty("useSSL", false, Messages.getString("ConnectionProperties.useSSL"), "3.0.2", SECURITY_CATEGORY, 2);
  // 省略...
 }
```

其中，`useSSL` 属性默认为 `false`。



如果版本号小于 5.1.38，则在创建MySQL 连接时， useSSL 参数会按照 `ConnectionPropertiesImpl` 初始化时默认值设置。



版本号大于等于 5.1.38 则在连接 MySQL 调用 MysqlIO#doHandshake( ) 时，对MySQL 版本 5.7+ ,如果 url 未设置 useSSL 参数

```java
void doHandshake(String user, String password, String database) throws SQLException {
  	// 省略..
  
          // Changing SSL defaults for 5.7+ server: useSSL=true, requireSSL=false, verifyServerCertificate=false
        if (versionMeetsMinimum(5, 7, 0) && !this.connection.getUseSSL() && !this.connection.isUseSSLExplicit()) {
            this.connection.setUseSSL(true);
            this.connection.setVerifyServerCertificate(false);
            this.connection.getLog().logWarn(Messages.getString("MysqlIO.SSLWarning"));
        }
  
    	// 省略..
}
```

`this.connection.getLog().logWarn(Messages.getString("MysqlIO.SSLWarning"))` 

会 warn 日志，要求我们需要在连接到 uri路径上设置 useSSL 参数

```java
Tue Apr 18 17:24:39 CST 2023 WARN: Establishing SSL connection without server's identity verification is not recommended. According to MySQL 5.5.45+, 5.6.26+ and 5.7.6+ requirements SSL connection must be established by default if explicit option isn't set. For compliance with existing applications not using SSL the verifyServerCertificate property is set to 'false'. You need either to explicitly disable SSL by setting useSSL=false, or set useSSL=true and provide truststore for server certificate verification.
```
