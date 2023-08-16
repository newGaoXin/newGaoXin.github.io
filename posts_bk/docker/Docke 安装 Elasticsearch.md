# Docke 安装 Elasticsearch

## 下载镜像

```shell
docker pull elasticsearch:7.4.2
```



## 创建实例

### 1.创建实例挂载的文件夹

```shell
mkdir -p /mydata/elasticsearch/config
mkdir -p /mydata/elasticsearch/data
echo "http.host: 0.0.0.0" >> /mydata/elasticsearch/config/elasticsearch.yml
```



### 2.文件夹读写权限

```shell
chmod -R 777 /mydata/elasticsearch/
```



3.创建实例

```shell
docker run --name elasticsearch -p 9200:9200 -p 9300:9300 \
-e "discovery.type=single-node" \
-e ES_JAVA_OPTS="-Xms64m -Xmx512m" \
-v /mydata/elasticsearch/config/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml \ 
-v /mydata/elasticsearch/data:/usr/share/elasticsearch/data \
-v /mydata/elasticsearch/plugins:/usr/share/elasticsearch/plugins \
-d elasticsearch:7.4.2
```

Note：小于512可能导致安装IK插件失败

## Docker 安装 Kibana 可视化界面

### 1.拉取镜像

```shell
docker pull kibana:7.4.2
```



### 2.创建实例

```shell
docker run --name kibana -e ELASTICSEARCH_HOSTS=http://192.168.56.10:9200 -p 5601:5601 -d kibana:7.4.2
```

note：http://192.168.56.10:9200 一定改为自己虚拟机的地址



## 设置镜像自动启动

```shell
sudo docker update 实例id --restart=always
```

