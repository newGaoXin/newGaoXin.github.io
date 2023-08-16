# Docker 安装 MySQL



## 常用指令

查看所有容器：

```shell
docker ps -a
```

进入容器：

```shell
docker exec -it 应用名称 /bin/bash
```

退出容器：

```shell
exit
```

设置容器自动启动：

```shell
docker update mysql --restart=always
```





## 安装 MySQL 5.7

运行容器：

```shell
docker run -p 3306:3306 --name mysql \
-v /mydata/mysql/log:/var/log/mysql \
-v /mydata/mysql/data:/var/lib/mysql \
-v /mydata/mysql/config:/etc/mysql \
-e MYSQL_ROOT_PASSWORD=root \
-d mysql:5.7
--character-set-server=utf8 --collation-server=utf8_unicode_ci
```

mysql的字符集编码配置 my.cnf文件：

```shell
[dient]
default-character-set=utf8

[mysql]
default-character-set=utf8

[mysqld]
init_connect='SET collation_connection = utf8_unicode_ci'
init_connect='SET NAMES utf8"
character-set-server=utf8
collation-server=utf8_unicode_ci
skip-character-set-client-handshake
skip-name-resolve
```



## M1 安装

拉去 mysql/mysql-server 下的镜像

需要进入容器，修改权限，**不修改无法使用IP登陆**

```shell
docker exec -it mysql5.7 bash
```

```shell
# 登陆mysql
mysql -uroot -p 

# 将root用户的Host 由 localhost 修改为 %
update mysql.user set Host = '%' where User = 'root';

# 刷新(刷新可以使用IP登陆，图形化界面登陆)
flush privileges;
```

