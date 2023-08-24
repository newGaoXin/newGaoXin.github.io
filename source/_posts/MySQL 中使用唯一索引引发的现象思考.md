---
title: MySQL 中使用唯一索引引发的现象思考
comments: true
date: 2023-08-24 23:08:10
tags:
- MySQL
categories:
- MySQL
description: 在项目中使用 MySQL 中唯一索引引发的现象，对其进行的思考记录
---

# 一、背景

我们的项目是以检查开展业务，可以增删改检查表，产品希望检查表进行权限设置，只有拥有指定权限的用户，才可以使用检查表。

在开发中我在数据库中创建了一张 `cehcksheet_use_permission`（检查表使用权限表）并使用了唯一索引去做约束

SQL：

```mysql
CREATE TABLE cehcksheet_use_permission(
	`id` bigint primary key AUTO_INCREMENT,
  `checksheet_id` bigint not null,
  `permission_id` bigint not null,
  UNIQUE INDEX checksheet_permission_u_index(`checksheet_id`,`permission_id`)
) 
```

项目数据库技术：MySQL InnoDB 存储引擎

# 二、现象

1. 当我分别对检查表id 100、101、102 设置了 权限id 120

   ```mysql
   INSERT INTO `cehcksheet_use_permission`(`checksheet_id`,`permission_id`) VALUES(100,120),(101,120),(102,120)
   ```

   数据库中看到的数据是

   | id   | checksheet_id | permission_id |
   | ---- | ------------- | ------------- |
   | 1    | 100           | 120           |
   | 2    | 101           | 120           |
   | 3    | 102           | 120           |

2. 当我再次分别对检查表id 100、101、102 设置了 权限id 90

   ```mysql
   INSERT INTO `cehcksheet_use_permission`(`checksheet_id`,`permission_id`) VALUES(100,90),(101,90),(102,90)
   ```

   数据库中看到的数据是

   | id   | checksheet_id | permission_id |
   | ---- | ------------- | ------------- |
   | 4    | 100           | 90            |
   | 1    | 100           | 120           |
   | 5    | 101           | 90            |
   | 2    | 101           | 120           |
   | 6    | 102           | 90            |
   | 3    | 102           | 120           |

   从第二次的批量插入数据可以看到，***<u>后插入的数据没有按照id去排序了，看起来像是根据联合唯一索引去排序了</u>***

3. 尝试第三次插入数据，验证想法，再次分别对检查表id 100、101、102 设置了 权限id 140

   ```sql
   INSERT INTO `cehcksheet_use_permission`(`checksheet_id`,`permission_id`) VALUES(100,140),(101,140),(102,140)
   ```

   数据库中看到的数据是

   | id   | checksheet_id | permission_id |
   | ---- | ------------- | ------------- |
   | 4    | 100           | 90            |
   | 1    | 100           | 120           |
   | 10   | 100           | 140           |
   | 5    | 101           | 90            |
   | 2    | 101           | 120           |
   | 11   | 101           | 140           |
   | 6    | 102           | 90            |
   | 3    | 102           | 120           |
   | 12   | 102           | 140           |

   证明了按照联合唯一索引去排序的想法，为什么会导致这样子呢？

# 三、分析

## 1 通过 SELECT * FROM 查询时，数据是如何排序的

### 1.1 SELECT * FROM 查询结果是按照主键id排序吗？

并不是，只是因为我们在创建一张表时，假设表只设置了主键，没有像本篇文章的情况一样还设置的唯一索引，那么通过 `SELECT * FROM` 查询结果看到数据结果是主键 ID 有序递增，只是因为在插入数据时，是按照了主键索引顺序去插入数据写入到磁盘中，所以当我们 `SELECT * FROM` 查询的时候，其实看到的是数据存储在磁盘的顺序。

所以在我的案例场景中，是不是联合索引打破了根据主键索引有序插入这个规则，导致我们看到的数据顺序是按照联合索引去排序的？



## 2 索引 INSERT 工作原理

在创建表的时候我设置了主键索引（`id`）以及联合唯一索引(` checksheet_permission_u_index`)



### 1.1 主键索引 INSERT 时工作原理

网上有很多现成的文章，找了几个不错的，我也就不在重复赘述找了几个帖子

1. [MySQL索引总结 - 知乎 (zhihu.com)](https://zhuanlan.zhihu.com/p/29118331)
2. [mysql为什么建议使用自增主键 - 知乎 (zhihu.com)](https://zhuanlan.zhihu.com/p/71022670)

总结：在 MySQL InnoDB 中当我们设置了主键索引。其实现时一个B+树（**聚簇索引**），在 INSERT 时，因为是主键自增，保证有了有序，所以可以直接在最后索引的最后插入数据，减少了页分裂，频繁的因为排序问题去重新维护B+树



### 1.2 唯一索引 INSERT 时工作原理

找到了两个关于这方面的文章帖子

1. [MySQL 普通索引和唯一索引的区别 - 禺期 - 博客园 (cnblogs.com)](https://www.cnblogs.com/hhhhuanzi/p/12318504.html)
2. https://stackoverflow.com/questions/28084901/how-does-mysql-determine-if-an-insert-is-unique
3. [深入探究Mysql联合索引的原理——B树|B+树|回表|联合索引|索引覆盖|索引失效_mysql 联合索引建树原理_coke007的博客-CSDN博客](https://blog.csdn.net/kexiaoleqq/article/details/118497584)

其实网上对于唯一索引的工作原理的资料很少，结合两篇文章的介绍，我猜测在 INSERT 时的工作原理（结合我的需求例子，忘记的可以回顾下）：

例如在我的案例场景中第二次 INSERT 的时候，插入的数据是 ``checksheet_id = 100` ,`permission_id = 90`

1. 会先根据联合唯一索引 `checksheet_permission_u_index(`checksheet_id`,`permission_id`)` 在索引树中匹配  ``checksheet_id = 100 `
2. 这时候找到第一个值 `checksheet_id = 100` ,`permission_id = 100` ，会去匹配联合唯一索引的第二个key `permission_id `
3. 因为联合索引是按照 key 进行排序维护，所以直接在 ``checksheet_id = 100` ,`permission_id = 100` 这个数据值时，直接比较 `permission_id` 是否等于 100，不等于则判断是否大于，大于继续往前找，小于则直接在前面插入数据，也就导致在案例场景第二次插入数据看到的结果

步骤 3 所带来的问题，由于按照唯一索引顺序插入数据，不是按照主键顺序是排序，也就会导致主键所维护的 B+树，要频繁的对主键索引树进行更新维护，是不是也会导致性能问题？


# 三、总结
由于创建了唯一索引在 INSERT 数据时，在磁盘中的插入位置是根据唯一索引来决定的，不是按照主键顺序插入数据，这可能会导致主键的索引树不断需要更新维护，代理性能问题，当我们在生产中使用唯一索引时，应该要思考，唯一索引是不是必须，有没有其他更好的解决方案
