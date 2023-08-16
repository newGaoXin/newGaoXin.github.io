# Docker 安装 Nginx

## 1.设置外部文件夹

随便启动一个 nginx 实例，只是为了复制出配置 

```shell
docker run -p 80:80 --name nginx -d nginx:1.10 
```

将容器内的配置文件拷贝到当前目录：

```shell
docker container cp nginx:/etc/nginx .
```

Note: 别忘了后面的点

修改文件名称：`mv nginx conf`把这个 conf 移动到 `/mydata/nginx` 下

终止原容器：

```she
docker stop nginx
```

执行命令删除原容器：

```shell
docker rm 容器ID
```



## 2.创建新的 Nginx 

```shell
docker run -p 80:80 --name nginx \
-v /mydata/nginx:/etc/nginx \
-d nginx:1.10
```



## 3.Nginx 反向代理 其他 Docker 容器

Docker 容器之间的网络是隔离的，需要将 Nginx 容器 和 要代理的容器加入到同一个网络中

### 3.1 创建网络命令

要在 Docker 中创建网络，可以使用以下命令：

```shell
docker network create <network_name>
```

其中 `<network_name>` 是您要创建的网络的名称。例如，要创建名为 `my_network` 的网络，可以运行以下命令：

```bash
docker network create my_network
```



### 3.2 容器加入网络

要将容器加入网络中，可以使用以下命令：

```bash
docker network connect my_network <container_name>
```

其中 `<container_name>` 是您要加入网络的容器的名称或 ID。例如，要将名为 `my_container` 的容器加入 `my_network` 网络，可以运行以下命令：

```bash
docker network connect my_network my_container
```

请注意，容器必须已经创建才能将其加入网络中。如果您在创建容器时要将其添加到网络中，请使用 `--network` 选项。例如：

```bash
docker run --name my_container --network my_network my_image
```

这将创建一个名为 `my_container` 的容器，并将其添加到 `my_network` 网络中。



### 3.3

期望 访问 http://127.0.0.1:80/test/index 可以代理到 http://127.0.0.1:80/index 

在 nginx.conf 配置 http 配置中添加 upstream backend

```bash
http {

    upstream backend {
        server <docker容器名称>:<端口号>;
    }

}
```

在 conf.d 文件夹下添加

```bash
    // 可以配置在 conf.d 文件夹下 文件后缀为 xxx.conf	就会被 nginx配置读取到
    server {
        listen 80;
        server_name localhost;

        location ~ /rs/ {
          rewrite ^/rs/(.*)$ /$1 break;
          proxy_pass http://backend;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

    }
```

