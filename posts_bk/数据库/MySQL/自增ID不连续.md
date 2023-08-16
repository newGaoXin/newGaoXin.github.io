# 自增ID不连续

在一次生产问题排查中，发现 Order库一个有趣的现象，Order 的主键 ID 设置了 `auto_increment` 自动递增

正常我们期望的是：1,2,3,4...100 一直连续递增

但是实际从生产库中数据看到的却是间隔的：1,2,3,6,7,45,67,68...100

当然作为一名经验丰富的 Java 程序员，肯定是事务嘛，两个事务同时进行了 `INSERT`，第一个事务 ID 为 1，第二个事务 ID 为 2，第一个事务由于手续操作异常，导致回滚，那么这时候第二个事务成功，那么数据库中看到的就是2

猜想有了要怎么证明呢，当然是查 MySQL 5.7 官方手册

省流助手：[14.6.1.6 AUTO_INCREMENT Handling in InnoDB]([MySQL :: MySQL 5.7 Reference Manual :: 14.6.1.6 AUTO_INCREMENT Handling in InnoDB](https://dev.mysql.com/doc/refman/5.7/en/innodb-auto-increment-handling.html#innodb-auto-increment-lock-modes)) 以下内容也是对文档进行翻译和个人理解，最直接暴力就是自己看文档

## InnoDB 的 auto_increment 

查阅文档

![auto_increateme lock mechaism](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/auto_increateme lock mechaism.png)

这里告诉我们其实 `auto_increment` 是 InnoDB 中一种可配置锁机制（既然是锁那么就会有互斥），要怎么进行配置呢？

![](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/auto_increment_lock_models_01.png)

`auto_increment` 是通过 `innodb_autoinc_lock_mode` 变量配置，在 MySQL 启动的时候会去读取



## innodb_autoinc_lock_mode

### 是什么？

![innodb_autoinc_lock_model variable](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/innodb_autoinc_lock_model variable.png)

`innodb_autoinc_lock_mode` 变量值可以是：0（traditional-传统锁定模式）、1（consecutive-连续锁定模式）、2（interleaved-交替锁定模式）

于是我通过 `show variables like 'innodb_autoinc_lock_mode'` 

<img src="/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/生产innodb_autoinc_lock_mode配置.png" alt="生产innodb_autoinc_lock_mode配置" style="zoom: 50%;" />

生产上是 MySQL 5.7 版本变量配置是 1（consecutive-连续模式）

## 前置知识

### `INSET-like` 语句

![inser-like statements](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/inser-like statements.png)

在表中生成新行的所有语句，包括 `INSERT`，`INSDERT...SELECT`，`REPLACE...SELECT` 以及`LOAD DATA`，包括 `simple-insert`，`bulk-inserts` 以及 `mixed-model`

### `Simple inserts` （简单的 inserts）

![simple inserts](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/simple inserts.png)

语句有哪些的行要插入是可以提前确定的（在语句最初的处理时），包含单行和多行的 `ISNERT` 和 `REPLACE` 语句，语句中不包含嵌套子查询（例如 `INSERT ... SELECT TABLE FROM ...` ）,但不包含 `INSERT...ON DUPLICATE KEY UPDATE`（这个语句可以判断 ID 重复更新，否则新增）

### `Bulk inserts` （批量 inserts）

![Bulk inserts](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/Bulk inserts.png)

语句有哪些行要插入（以及要自增的值）是无法提前知道的，包含 `INSERT ... SELECT `,`REPLACE ... SELECT` 以及 `LOAD DATA` 语句，

InnoDB 会每次给一个自增字段分配一个新的值

### `Mixed-mode inserts`（混合模式 inserts）

![image-20220827203823927](/Users/newgaoxin/Library/Application Support/typora-user-images/image-20220827203823927.png)

这些特殊的 ”simple insert“ 语句，会为新行指定自增值，例如上面的 SQL 例子；

另一种类型的混合插入 `NSERT ... ON DUPLICATE KEY UPDATE` ，最坏的情况的结果是有`INSERT` 和 `UPDATE` ，自增字段分配值，可能在update 阶段使用也可以不被使用



## `innodb_autoinc_lock_mode = 1` (“consecutive” lock mode) （连续锁模式）

!["consecutive" lock mode (01)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/"consecutive" lock mode (01).png)

 `innodb_autoinc_lock_mode = 1` 是默认模式，（这也是前面通过查询变量为什么数据库设置值的是 1），在这个模式中，“bulk inserts” （批量插入）使用特别的表级锁 AUTO-INC 一直到语句结束，适用于所有的 `INSERT ... SELECT`,`REPLACE ... SELECT` 以及 `LOAD DATA` 语句，一次只能执行一个持有 AUTO-INC 锁的语句，如果批量操作的原表和目标表不同，拿到源表被选中首行的共享锁之后，持有目标表的 AUTO-INC 锁，如果批量操作的源表和目标表是在同一张表上，获取到所有被选中行的共享锁之后持有 AUTO-INC 锁。



!["consecutive" lock mode (02)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/"consecutive" lock mode (02).png)

“Simple inserts”（能够提前确定要插入的行数量）仅仅在分配期间利用互斥锁进行控制，获取所需的数量的自增值，避免表级锁 AUTO-INC，不会持有锁到语句结束；除非另外一个事务持有表级锁 AUTO-INC（也就是另外一个事务进行 “bulk inserts” 操作），否则不会使用表级锁 AUT-INC，如果另外一个事务持有表级锁 AUTO-INC，“Simple inserts” 会等待表级锁 AUTO-INC，它就像是一个 “bulk inserts” 操作。（这里是只等待不会获取表级锁吗？）



!["consecutive" lock mode (03)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/"consecutive" lock mode (03).png)

这种锁定模式确保了，在事先不是知道 `INSERT` 语句要插入多少行数到情况下，任何 “INSERT-LIKE” 语句所有自增值的分配都是连续的，并且基于语句替换（应该是指 `REPLACE ... SELECT` 语句）的操作的都是安全的。



!["consecutive" lock mode (04)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/"consecutive" lock mode (04).png)

简而言之，这种锁定模式显著提高了可伸缩性性，同时基于语句的复制又可以安全的使用。此外，与 “traditional” 锁定模式一样，给所有语句分配的自增值都是连续的，所有语句使用 auto-increment 的语义与 “traditional” 锁定模式没有变化，只有一个例外。



!["consecutive" lock mode (05)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/"consecutive" lock mode (05).png)

这个例外是 “Mixed-mode inserts” ，在一个 “simple insert” 语句当中，用户为一部分自增字段指定了自增值，但不是全部，对于此类的 `INSERT` ，InnoDB 会分配比要 `INSERT` 的行数更多的自增值，然而，所有自动分配的值，都是连续生成的，因为会比前一次语句执行所生成的自增值更大，多余的自增值就丢失了。（这里是导致自增 ID 不连续的原因一）



## InnnoDB AUTO_INCREMENT Lock Mode Usage Implications（InnoDB AUTO_INCREMENT 锁模式可能存在一些问题）

### 1.Auto-increment 与复制同时使用（这里讲的是主从数据复制）

![](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/InnoDB AUTO_INCREMENT Lock Mode Usage Implications (1).png)

如果你使用的基于 SQL 语句的复制，设置 `innodb_autoinc_lock_mode` 为 0 或者 1并且源以及副本上使用相同的值，如果你使用 `innodb_autoinc_lock_mode = 2` （交叉模式）或者在源和副本上不使用相同的锁模式的配置，则无法确保 auto-increment 的值在源和副本中是相同的。（这里的源和副本是主从数据的复制）

如果你使用基于 ROW 或者混合格式的复制模式（混合 = 基于 SQL 语句的复制 + 基于 ROW 复制）所有的自增锁模式都是安全的，因为基于 ROW 复制对于SQL 语句的执行顺序不敏感（混合模式对任何基于 SQL 语句复制不安全的语句使用基于 ROW 复制）



### 2.丢失的 auto-increment 值与序列间隙

![InnoDB AUTO_INCREMENT Lock Mode Usage Implications (2)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/InnoDB AUTO_INCREMENT Lock Mode Usage Implications (2).png)

在所有的锁模式中，如果一个事务中生成 auto-increment 值发生了回滚，那么 auto-increment 值会丢失，一旦 auto-increment 字段生成了值，是不会被回滚的，无论 “INSERT-like” 语句是否完成，无论当前事务是否被回滚，这种情况下丢失的值不能再使用到，因为在一个表设置 AUTO_INCREMENT 的字段有可能存在间隙（自增 ID 不连续的愿意二）



### 3.设置了 AUTO_INREMENT 的字段指定 NULL 值或者 0 值

![InnoDB AUTO_INCREMENT Lock Mode Usage Implications (3)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/InnoDB AUTO_INCREMENT Lock Mode Usage Implications (3).png)

在所有锁模式，如果用户在一条 `INSERT` 语句中给 auto_increment 字段指定了 `NULL` 或者 0 ，InnoDB 会当作没有指定值并且会去生成新的自增值给它。



### 4.分配负值给 `AUTO_INCREMENT` 字段

![InnoDB AUTO_INCREMENT Lock Mode Usage Implications (4)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/InnoDB AUTO_INCREMENT Lock Mode Usage Implications (4).png)

在所有锁模式中，当你分配负值给设置了 `AUTO_INCREMENT` 字段，这个行为会导致数据库引擎 auto-increment 机制失效（官方文档中用  undefined 未定义来描述，在我的实际测试指定什么负值就会插入什么负值，这里用失效可能更准确）

tip：实际测试会按照负值插入



### 5.如果 `AUTO_INCREMENT` 值大于指定的整数类型最大值

![InnoDB AUTO_INCREMENT Lock Mode Usage Implications (5)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/InnoDB AUTO_INCREMENT Lock Mode Usage Implications (5).png)

在所有锁模式中，如果设置了 `AUTO_INCREMENT` 字段的值增长大于该字段定义到整数类型可以存储的最大值，这个行为会让 auto-increment 机制失效；

tip：实际测试，数据库会生成能存储的最大值，插入的时候就会提示主键重复异常

<img src="/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/如果 `AUTO_INCREMENT` 值大于指定的整数类型最大值测试.png" alt="如果 `AUTO_INCREMENT` 值大于指定的整数类型最大值测试" style="zoom:50%;" />



### 6.“bulk insert”（批量插入）自增值的间隙

![InnoDB AUTO_INCREMENT Lock Mode Usage Implications (6)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/InnoDB AUTO_INCREMENT Lock Mode Usage Implications (6).png)

当 `innnodb_autoinc_lock_mode` 设置为 0（“traditional”）或者 1（“consecutive”）模式时，任何语句获得的自增值都是连续的，没有间隙（这里应该指的是一条批量插入获得的一批自增值是连续没有间隙的），因为表级锁 AUTO-INC 锁一直持有锁到语句执行结束，但一次只有执行一条语句。

当 `innnodb_autoinc_lock_mode` 设置 2 （“interleaved“）模式，“bulk insert” 生产的自增值可能存在间隙，当然只有在同时执行 “INSERT-LIKE” 语句的时候。

对于 1 和 2 锁模式，连续语句之间可能存在间隙（连续的批量插入语句），因为每条 “bulk insert” 语句具体需要分配多少自增值无法确定，还有可能多于需要分配的（如果要插入的数据，在自增字段部分指定值，部分未指定，那么就有高估的情况）。



### 7.“mixed-mode inserts” 下 auto-increment 值的分配

![InnoDB AUTO_INCREMENT Lock Mode Usage Implications (7)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/InnoDB AUTO_INCREMENT Lock Mode Usage Implications (7).png)

“mixed-mode inserts”（混合模式插入）下，一条“simple insert”（简单插入）指定部分自增值但没有全部指定自增值字段的值，这种行为在锁模式 0（“traditional”）、1（“consecutive”）以及 2 （“interleaved“）下不同，例如，假设在表 t1 中 c1 是一个设置了 `AUTO_INCREMENT` 的字段，并且之前的一句连续生产自增值到100。

```mysql
mysql> CREATE TABLE t1 (
    -> c1 INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, 
    -> c2 CHAR(1)
    -> ) ENGINE = INNODB;
```

因为我们使用的是 mysql 5.7 默认配置是 1 下面只看关于 1（”consecutive“）模式下的分析

请考虑下面 SQL 语句

```mysql
mysql> INSERT INTO t1 (c1,c2) VALUES (1,'a'), (NULL,'b'), (5,'c'), (NULL,'d');
```

当 `innodb_autoinc_lock_mode` 设置为 1（”consecutive“）模式，结果如下：

```mysql
mysql> SELECT c1, c2 FROM t1 ORDER BY c2;
+-----+------+
| c1  | c2   |
+-----+------+
|   1 | a    |
| 101 | b    |
|   5 | c    |
| 102 | d    |
+-----+------+
```

![InnoDB AUTO_INCREMENT Lock Mode Usage Implications (8)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/InnoDB AUTO_INCREMENT Lock Mode Usage Implications (8).png)

这个例子，下一个可用的自增值是 105，不是 103，因为在一次 “mixed-mode inserts” 语句的执行中分配了四个自增值，但是只有两个值被使用到了，这个结果是正确的，无论是否执行了是否同时执行了 “INSERT-like” 语句（及任何类型的 INSERT 语句）

最后考虑下面这个 SQL 语句，当最近一次生产的自增值是100是：

```mysql
mysql> INSERT INTO t1 (c1,c2) VALUES (1,'a'), (NULL,'b'), (101,'c'), (NULL,'d');
```

![InnoDB AUTO_INCREMENT Lock Mode Usage Implications (9)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/InnoDB AUTO_INCREMENT Lock Mode Usage Implications (9).png)

在任何 `innodb_autoinc_lock_mode` 设置中，这个 SQL 语句会产生一个 key 重复异常提示（Can't write; duplicate key in table），因为 101 在插入到 `(NULL,'b')` 时已经分配了，所以当插入 `(101,'c')` 时会失败。



8.修改 设置了 `AUTO_INCREMENT` 字段中 INSERT 语句生产的值

![InnoDB AUTO_INCREMENT Lock Mode Usage Implications (10)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/InnoDB AUTO_INCREMENT Lock Mode Usage Implications (10).png)

在所有锁模式中 0（“traditional”）、1（“consecutive”）以及 2 （“interleaved“），修改一个设置了 `AUTO_INCREMENT` 字段由 `INSERT` 语句生成的值，会导致 key 值重复（ “Duplicate entry” ）异常，一个例子，如果你使用 `UPDATE` 操作变更了一个设置了 `AUTO_INREMENT`字段的值使他比当前 auto-increment 值更大，随后操作 `INSERT` 但不指定一个未被使用的自增值，会遇到key 值重复（ “Duplicate entry” ）异常，这个行为在下面的例子中证明：

```mysql
mysql> CREATE TABLE t1 (
    -> c1 INT NOT NULL AUTO_INCREMENT,
    -> PRIMARY KEY (c1)
    ->  ) ENGINE = InnoDB;

mysql> INSERT INTO t1 VALUES(0), (0), (3);

mysql> SELECT c1 FROM t1;
+----+
| c1 |
+----+
|  1 |
|  2 |
|  3 |
+----+

mysql> UPDATE t1 SET c1 = 4 WHERE c1 = 1;

mysql> SELECT c1 FROM t1;
+----+
| c1 |
+----+
|  2 |
|  3 |
|  4 |
+----+

mysql> INSERT INTO t1 VALUES(0);
ERROR 1062 (23000): Duplicate entry '4' for key 'PRIMARY'
```



## InnoDB `AUTO_INCREMENT` 计数器的初始化

![InnoDB AUTO_INCREMENT Lock Mode Usage Implications (11)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/InnoDB AUTO_INCREMENT Lock Mode Usage Implications (11).png)

如果你在一张 InnoDB 引擎的表中指定了一个 `AUTO_INCREMENT` 字段，在 InnoDB 数据字典中会包含一个称为自增值计算器，用于为该字段分配新值，这个计算器存储在主内存中，而不是磁盘上。

![InnoDB AUTO_INCREMENT Lock Mode Usage Implications (12)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/InnoDB AUTO_INCREMENT Lock Mode Usage Implications (12).png)

自增计数器在服务启动之后初始化，InnoDB 执行下面的 SQL 语句等同于第一次插入一个表含有的 `AUTO_INCREMENT` 字段

```mysql
SELECT MAX(ai_col) FROM table_name FOR UPDATE;
```

![InnoDB AUTO_INCREMENT Lock Mode Usage Implications (13)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/InnoDB AUTO_INCREMENT Lock Mode Usage Implications (13).png)

InnoDB 自增值被语句取得时，会分配给表的字段和自增计数器，默认情况下，自增值为1，设置`auto_increment_increment` 配置覆盖可以这个默认值

![InnoDB AUTO_INCREMENT Lock Mode Usage Implications (14)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/InnoDB AUTO_INCREMENT Lock Mode Usage Implications (14).png)

如果是一个空表，InnoDB 使用 1 作为默认值，可以设置 `auto_increment_offset` 配置覆盖这个默认值（这里官方文档应该是表示自增步长）

![InnoDB AUTO_INCREMENT Lock Mode Usage Implications (15)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/InnoDB AUTO_INCREMENT Lock Mode Usage Implications (15).png)

如果在自增计数器初始化完成之前使用 `SHOW TABLE STATUS` 语句检查表，InnoDB 初始化但没有自增这个值，后续的 insert 操作存储使用这个值，初始化使用一个普通的独占锁读取这个表并且锁持有到事务结束，InnoDB 遵循相同的程序完成程序计数器的初始化。

![InnoDB AUTO_INCREMENT Lock Mode Usage Implications (16)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/InnoDB AUTO_INCREMENT Lock Mode Usage Implications (16).png)

自增计数器完成初始化之后，如果你没有明确指定一个值给 `AUTO_INCREMENT` 字段（这里是指在插入数据时），InnoDB 会自增计数器并把这个心智分配给该字段，如果你在插入一行数据时明确指定来字段的值，并且这个值比当前自增计数器的值更大，计数器会设置为该字段的指定值。

![InnoDB AUTO_INCREMENT Lock Mode Usage Implications (17)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/InnoDB AUTO_INCREMENT Lock Mode Usage Implications (17).png)

只要服务器运行，InnoDB 就会使用内存中的自增计数器，当服务停止并重启，InnoDB 会在每个表第一次 `INSERT` 数据到表中时重新初始化自增计数器。

![InnoDB AUTO_INCREMENT Lock Mode Usage Implications (18)](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/InnoDB AUTO_INCREMENT Lock Mode Usage Implications (18).png)

在 `CREATE_TABLE` 或者 `ALTER_TABLE` 中使用 `AUTO_INCREMENT = N` 语句可以让服务重启会让初始化自增计数器失效，你可以用在 InnoDB 表中设置初始化自增计数器值或者改变当前的计数器值。



## Note

![note](/Users/newgaoxin/development/code/myNotes/数据库/MySQL/image/note.png)

- 当 `AUTO_INCREMENT` 整数字段值超出最大值时，随着 `INSERT` 操作返回一个 key 重复一次（duplicate-key error）。
- 当你重启 MySQL 服务，InnoDB 可能重用旧值会为 `AUTO_INCREMENT` 字段生成，但永远不会存储（即使在旧的事务中生成被回滚的值）