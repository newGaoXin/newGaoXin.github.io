# m1 Docker 安装 Nacos

## 拉取适合m1的镜像。 

```shell
docker pull zhusaidong/nacos-server-m1:2.0.3
```



## 启动容器

### 单机

```shell
docker run -d -p 8848:8848 -p 9848:9848 -p 9555:9555 --name nacos-server \
-e PREFER_HOST_MODE=hostname \
-e MODE=standalone \
-e SPRING_DATASOURCE_PLATFORM= \
-e MYSQL_SERVICE_HOST=127.0.0.1 \
-e MYSQL_SERVICE_DB_NAME=nacos \
-e MYSQL_SERVICE_PORT=3306 \
-e MYSQL_SERVICE_USER=root \
-e MYSQL_SERVICE_PASSWORD= \
-e MYSQL_SERVICE_DB_PARAM=allowPublicKeyRetrieval=true \
zhusaidong/nacos-server-m1:2.0.3
```



### 集群

```shell
# nacos-cluster1
docker run -d \
-e PREFER_HOST_MODE=hostname \
-e MODE=cluster \
-e NACOS_APPLICATION_PORT=8848 \
-e NACOS_SERVERS="192.168.96.126:8848 192.168.96.126:8948" \
-e SPRING_DATASOURCE_PLATFORM=mysql \
-e MYSQL_SERVICE_HOST=192.168.96.126 \
-e MYSQL_SERVICE_PORT=3306 \
-e MYSQL_SERVICE_USER=root \
-e MYSQL_SERVICE_PASSWORD=123456 \
-e MYSQL_SERVICE_DB_NAME=nacos \
-e NACOS_SERVER_IP=192.168.96.126 \
-p 8848:8848 \
--name my-nacos1 \
zhusaidong/nacos-server-m1:2.0.3

# nacos-cluster2
docker run -d \
-e PREFER_HOST_MODE=hostname \
-e MODE=cluster \
-e NACOS_APPLICATION_PORT=8948 \
-e NACOS_SERVERS="192.168.96.126:8848 192.168.96.126:8948" \
-e SPRING_DATASOURCE_PLATFORM=mysql \
-e MYSQL_SERVICE_HOST=192.168.96.126 \
-e MYSQL_SERVICE_PORT=3306 \
-e MYSQL_SERVICE_USER=root \
-e MYSQL_SERVICE_PASSWORD=123456 \
-e MYSQL_SERVICE_DB_NAME=nacos \
-e NACOS_SERVER_IP=192.168.96.126 \
-p 8948:8948 \
--name my-nacos2 \
zhusaidong/nacos-server-m1:2.0.3
```