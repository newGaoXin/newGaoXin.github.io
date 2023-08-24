---
title: （未完成）Spring Security 去除默认密码生成
comments: true
date: 2023-08-22 19:56:09
tags:
- Spring
- Spring Security
categories:
- Spring Security
description: 最近做的一个项目，项目是由公司的架构师搭建的，使用了 Spring Security，但是每次启动控制台日志都会提示生成默认密码，之前遇到的项目都使用了都会把这个去掉，想是不是公司架构师在使用 Spring Security 的时候没有做的那么完美，由此写下这篇文章
---



# 起因

最近做的一个项目，项目是由公司的架构师搭建的，使用了 Spring Security，但是每次启动控制台日志都会提示生成默认密码，之前遇到的项目都使用了都会把这个去掉，想是不是公司架构师在使用 Spring Security 的时候没有做的那么完美，由此写下这篇文章



## 项目技术架构

Spring Boot 全家桶

# Spring Security 怎么自动生成默认密码

默认密码的生成，是由 `spring-boot-autoconfigure `包下 `UserDetailsServiceAutoConfiguration ` 自动配置类，来完成的

## UserDetailsServiceAutoConfiguration

```java
@AutoConfiguration
@ConditionalOnClass(AuthenticationManager.class)
@ConditionalOnBean(ObjectPostProcessor.class)
@ConditionalOnMissingBean(
		value = { AuthenticationManager.class, AuthenticationProvider.class, UserDetailsService.class,
				AuthenticationManagerResolver.class },
		type = { "org.springframework.security.oauth2.jwt.JwtDecoder",
				"org.springframework.security.oauth2.server.resource.introspection.OpaqueTokenIntrospector",
				"org.springframework.security.oauth2.client.registration.ClientRegistrationRepository",
				"org.springframework.security.saml2.provider.service.registration.RelyingPartyRegistrationRepository" })
public class UserDetailsServiceAutoConfiguration {
  
 	@Bean
	@Lazy
	public InMemoryUserDetailsManager inMemoryUserDetailsManager(SecurityProperties properties,
			ObjectProvider<PasswordEncoder> passwordEncoder) {
		SecurityProperties.User user = properties.getUser();
		List<String> roles = user.getRoles();
		return new InMemoryUserDetailsManager(User.withUsername(user.getName())
			.password(getOrDeducePassword(user, passwordEncoder.getIfAvailable()))
			.roles(StringUtils.toStringArray(roles))
			.build());
	}

	private String getOrDeducePassword(SecurityProperties.User user, PasswordEncoder encoder) {
		String password = user.getPassword();
		if (user.isPasswordGenerated()) {
			logger.warn(String.format(
					"%n%nUsing generated security password: %s%n%nThis generated password is for development use only. "
							+ "Your security configuration must be updated before running your application in "
							+ "production.%n",
					user.getPassword()));
		}
		if (encoder != null || PASSWORD_ALGORITHM_PATTERN.matcher(password).matches()) {
			return password;
		}
		return NOOP_PASSWORD_PREFIX + password;
	}

}
```

### 注解解读

- `@AutoConfiguration` ：标识是一个自动配置类
- `@ConditionalOnClass(AuthenticationManager.class)`：当 `AuthenticationManager.class`  仅当指定的类位于类路径上时才匹配
- `@ConditionalOnBean(ObjectPostProcessor.class)`：当 ObjectPostProcessor.class Bean 存在时加载
- `@ConditionalOnMissingBean` 仅当中 BeanFactory 未包含满足指定要求的 Bean 时，才匹配

## 分析

如果我们想要在启动项目时，不生成默认的密码只要违背 `@ConditionalOnMissingBean` 中的条件就可以，即将注解中 

class 属性指定的

- `AuthenticationManager.class`
- `AuthenticationProvider.class`
- `UserDetailsService.class`
- `AuthenticationManagerResolver.class`

以及 type 属性指定的

- `org.springframework.security.oauth2.jwt.JwtDecoder`
- `org.springframework.security.oauth2.server.resource.introspection.OpaqueTokenIntrospector`
- `org.springframework.security.oauth2.client.registration.ClientRegistrationRepository`
- `org.springframework.security.saml2.provider.service.registration.RelyingPartyRegistrationRepository`

实现其中任意一个类并注册进 Fatory Bean 中即可，下面我们分别介绍下这些类的作用



## AuthenticationManager.class

作用：身份管理器负责验证这个`Authentication`







