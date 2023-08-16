# Docker 安装 Redis

## 拉取 Redis 镜像

```shell
docker pull redis
```

## 创建容器

```shell
mkdir -p /mydata/redis/conf
touch /mydata/redis/conf/redis.conf

docker run -p 6379:6379 --name redis -v /mydata/redis/data:/data \
-v /mydata/redis/conf/redis.conf:/etc/redis/redis.conf \
-d redis redis-server /etc/redis/redis.conf
```

进入 Redis 容器客户端

```shell
docker exec -it redis redis-cli
```



## 配置

修改 redis.conf 文件

### 持久化配置

```she
appendonly yes
```



