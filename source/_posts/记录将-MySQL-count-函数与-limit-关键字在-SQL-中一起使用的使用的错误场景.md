---
title: 记录将 MySQL count() 函数与 limit 关键字在 SQL 中一起使用的错误场景
comments: true
date: 2023-11-11 14:27:21
tags:
- MySQL
categories:
- MySQL
description: 实际项目中错误使用的一个记录
---



## 一、背景（是什么）

在一直的认知中在 MySQL当使用 count() 函数时，如果要使用 limit 限制 count 函数统计的最大值，SQL 写成以下例句：

```sql
select count(1) from a limit 10
```

但在一次实际工作中发现，这么使用 `limit` 关键字，并没有按照我的预期，只返回一条数据的统计结果

<!--more-->

## 二、为什么？

这个主要跟 MySQL SQL查询执行顺序顺序有关系，`limit` 关键字是对返回数量进行限制，而 `count()` 函数 在 `from` 执行后，只返回一条统计总数的数据，所以才会导致 limit 无效

官方文档：

[MySQL :: MySQL 8.0 Reference Manual :: 8.2.1.19 LIMIT Query Optimization](https://dev.mysql.com/doc/refman/8.0/en/limit-optimization.html)



## 三、怎么做？

必须使用子查询才可以，例句如下：

```sql
select count(1) from (select * from a limit 10) t
```

只有这种写法才可以不使子查询失效。



## 四、关于 `count()` 函数

在这个问题讨论中，项目的后端负责人，提到说 `count()` 函数其实是一个分组函数

但是从官方的文档来看，我们应该把 `count()` 一类的叫做聚合函数，跟分组函数应该是不同的概念

我理解上的不同：

聚合函数：会把结果聚合在一起

分组函数：会根据规则来分组
