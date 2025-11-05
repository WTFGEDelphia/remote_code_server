# SSH Docker 容器项目

## 项目概述

本项目提供了一个完整的 Docker 解决方案，用于在容器中运行 SSH 服务，基于 Ubuntu 25.10 镜像。

## 文件结构

```
├── Dockerfile           # 主要的 Docker 构建文件
├── docker-compose.yml   # Docker Compose 配置
├── .dockerignore        # Docker 构建忽略文件
├── build.sh            # 自动化构建脚本
└── README.md           # 详细使用说明
```

## 快速开始

### 方法 1: 使用自动化脚本（推荐）

```bash
# 构建并运行容器
./build.sh build

# 或者分步执行
./build.sh run    # 仅运行容器
./build.sh test   # 测试 SSH 连接
./build.sh shell  # 进入容器 shell
./build.sh logs   # 查看容器日志
./build.sh stop   # 停止容器
```

### 方法 2: 使用 Docker 命令

```bash
# 构建镜像
docker build -t ubuntu-ssh:25.10 .

# 运行容器
docker run -d -p 2022:2022 --name ubuntu-ssh-container ubuntu-ssh:25.10

# 测试连接
ssh ossapp@localhost -p 2022
# 密码: ossapp
```

### 方法 3: 使用 Docker Compose

```bash
# 启动服务
docker-compose up -d

# 查看状态
docker-compose ps

# 查看日志
docker-compose logs -f ssh-server

# 停止服务
docker-compose down
```

## 配置详情

### SSH 服务配置
- **端口**: 2022
- **用户**: ossapp
- **认证**: 密码认证
- **配置文件**: /etc/ssh/sshd_config
- **安全特性**: 禁用 root 用户登录

### 关键配置项
```bash
# 端口配置
Port 2022

# 禁用 root 用户登录
PermitRootLogin no

# 只允许 ossapp 用户登录
AllowUsers ossapp

# 启用密码认证
PasswordAuthentication yes
```

## 安全建议

⚠️ **重要**: 当前配置仅用于开发和测试环境

1. **修改默认密码**: 生产环境中必须修改 root 密码
2. **使用 SSH 密钥**: 建议使用密钥认证替代密码认证
3. **限制访问**: 使用防火墙限制访问源 IP
4. **更新镜像**: 定期更新基础镜像和依赖包

## 故障排除

### 常见问题

1. **SSH 连接失败**
   ```bash
   # 检查容器是否运行
   docker ps | grep ubuntu-ssh-container
   
   # 检查端口映射
   docker port ubuntu-ssh-container
   
   # 查看容器日志
   docker logs ubuntu-ssh-container
   ```

2. **容器无法启动**
   ```bash
   # 重新构建镜像
   docker build --no-cache -t ubuntu-ssh:25.10 .
   ```

3. **SSH 服务异常**
   ```bash
   # 进入容器检查
   docker exec -it ubuntu-ssh-container /bin/bash
   
   # 检查 SSH 服务状态
   ps aux | grep sshd
   
   # 检查配置文件
   cat /etc/ssh/sshd_config
   ```

## 自定义配置

### 修改 SSH 端口
编辑 `Dockerfile` 中的端口配置：
```dockerfile
RUN sed -i 's/#Port 22/Port YOUR_PORT/g' /etc/ssh/sshd_config
EXPOSE YOUR_PORT
```

### 添加更多用户
当前已配置 ossapp 用户，如需添加更多用户，在 Dockerfile 中添加：
```dockerfile
RUN useradd -m -s /bin/bash youruser && \
    echo 'youruser:yourpassword' | chpasswd && \
    # 更新 SSH 配置允许新用户
    echo "AllowUsers ossapp youruser" >> /etc/ssh/sshd_config
```

或者在容器运行时添加：
```bash
# 进入容器
docker exec -it ubuntu-ssh-container /bin/bash

# 创建新用户
useradd -m -s /bin/bash newuser
echo 'newuser:newpassword' | chpasswd

# 重新加载 SSH 配置
service ssh reload
```

### 挂载配置文件
使用 Docker Compose 挂载自定义配置：
```yaml
services:
  ssh-server:
    volumes:
      - ./custom-sshd_config:/etc/ssh/sshd_config
```

## 监控和维护

### 监控命令
```bash
# 查看资源使用
docker stats ubuntu-ssh-container

# 查看连接日志
docker exec ubuntu-ssh-container tail -f /var/log/auth.log

# 监控 SSH 进程
docker exec ubuntu-ssh-container ps aux | grep sshd
```

### 备份和恢复
```bash
# 备份容器
docker commit ubuntu-ssh-container ubuntu-ssh-backup

# 恢复容器
docker run -d -p 2022:2022 --name ubuntu-ssh-restored ubuntu-ssh-backup
```

## 许可证

本项目仅供学习和测试使用。