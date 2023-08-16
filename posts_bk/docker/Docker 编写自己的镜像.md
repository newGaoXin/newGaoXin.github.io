# Docker 编写自己的镜像

## 1.编写一个Java应用



## 2.编写Dockerfile并且打包

```dockerfile
FROM openjdk:8-jdk-slim
LABEL maintainer=newgaoxin

COPY target/*.jar   /app.jar

ENTRYPOINT ["java","-jar","/app.jar"]
```

FROM 表示需要依赖的基础镜像

LABEL maintainer=xxxxx  表示作者信息

COPY /目标应用的路径   /镜像容器中应用的位置

ENTRYPOINT ["xx","xx","xxx"] 镜像启动参数



3.Docker命令构造镜像

```bash
docker build -t java-demo:v1.0 -f Dockerfile .
# -t java-demo:v1. 生成的镜像名称和版本号
# -f Dockerfile Dockerfile文件名称
# . 指的是 Dockerfile 文件的路径位置
```

