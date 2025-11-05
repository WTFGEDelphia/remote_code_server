# 自定义 SSH 配置文件示例

## 使用自定义用户配置

### 1. 创建自定义 Dockerfile

```dockerfile
FROM ubuntu:25.10

ENV DEBIAN_FRONTEND=noninteractive

# 安装 OpenSSH Server
RUN apt-get update && \
    apt-get install -y openssh-server && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 创建 SSH 目录
RUN mkdir -p /var/run/sshd

# 创建多个用户
RUN useradd -m -s /bin/bash ossapp && \
    useradd -m -s /bin/bash developer && \
    useradd -m -s /bin/bash admin && \
    echo 'ossapp:ossapp123' | chpasswd && \
    echo 'developer:dev123' | chpasswd && \
    echo 'admin:admin123' | chpasswd && \
    usermod -aG sudo developer && \
    usermod -aG sudo admin

# 配置 SSH 服务
RUN sed -i 's/#Port 22/Port 2022/g' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config && \
    echo "AllowUsers ossapp developer admin" >> /etc/ssh/sshd_config && \
    echo "DenyUsers root" >> /etc/ssh/sshd_config

# 创建用户目录并设置权限
RUN mkdir -p /home/ossapp /home/developer /home/admin && \
    chown -R ossapp:ossapp /home/ossapp && \
    chown -R developer:developer /home/developer && \
    chown -R admin:admin /home/admin

EXPOSE 2022

CMD ["/usr/sbin/sshd", "-D"]
```

### 2. 使用环境变量自定义用户

```dockerfile
FROM ubuntu:25.10

ENV DEBIAN_FRONTEND=noninteractive

# 安装 OpenSSH Server
RUN apt-get update && \
    apt-get install -y openssh-server && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 创建 SSH 目录
RUN mkdir -p /var/run/sshd

# 使用环境变量创建用户（通过构建时传入）
ARG SSH_USER=ossapp
ARG SSH_PASSWORD=ossapp123

RUN useradd -m -s /bin/bash ${SSH_USER} && \
    echo "${SSH_USER}:${SSH_PASSWORD}" | chpasswd

# 配置 SSH 服务
RUN sed -i 's/#Port 22/Port 2022/g' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config && \
    echo "AllowUsers ${SSH_USER}" >> /etc/ssh/sshd_config

# 创建用户目录
RUN mkdir -p /home/${SSH_USER} && \
    chown -R ${SSH_USER}:${SSH_USER} /home/${SSH_USER}

EXPOSE 2022

CMD ["/usr/sbin/sshd", "-D"]
```

构建时使用自定义参数：
```bash
docker build --build-arg SSH_USER=myuser --build-arg SSH_PASSWORD=mypassword -t custom-ssh .
```

### 3. 运行时动态创建用户

创建脚本 `create-user.sh`：

```bash
#!/bin/bash

# 创建用户脚本
USERNAME=$1
PASSWORD=$2

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "用法: $0 <用户名> <密码>"
    exit 1
fi

# 创建用户
useradd -m -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

# 更新 SSH 配置允许新用户
CURRENT_ALLOW=$(grep "^AllowUsers" /etc/ssh/sshd_config | cut -d' ' -f2-)
NEW_ALLOW="$CURRENT_ALLOW $USERNAME"
sed -i "s/^AllowUsers.*/AllowUsers $NEW_ALLOW/" /etc/ssh/sshd_config

# 重新加载 SSH 配置
service ssh reload

echo "用户 $USERNAME 创建成功"
```

在 Dockerfile 中添加：

```dockerfile
# 复制用户创建脚本
COPY create-user.sh /usr/local/bin/create-user.sh
RUN chmod +x /usr/local/bin/create-user.sh

# 暴露额外端口（如果需要）
EXPOSE 2022 22

# 启动 SSH 服务和用户创建服务
CMD ["/bin/bash", "-c", "/usr/sbin/sshd -D & /usr/local/bin/create-user.sh additionaluser additionalpass && wait"]
```

### 4. 使用 Docker Compose 动态配置

```yaml
version: '3.8'

services:
  ssh-server:
    build: .
    container_name: ubuntu-ssh-container
    ports:
      - "2022:2022"
    environment:
      - SSH_USER=ossapp
      - SSH_PASSWORD=ossapp123
      - ADDITIONAL_USERS=developer:dev123,admin:admin123
    volumes:
      - ./users-setup.sh:/usr/local/bin/users-setup.sh
      - ssh-data:/home
    command: |
      bash -c "
        /usr/local/bin/users-setup.sh &&
        /usr/sbin/sshd -D
      "
    networks:
      - ssh-network

networks:
  ssh-network:
    driver: bridge

volumes:
  ssh-data:
    driver: local
```

创建 `users-setup.sh` 脚本：

```bash
#!/bin/bash

# 设置默认用户
if [ ! -z "$SSH_USER" ] && [ ! -z "$SSH_PASSWORD" ]; then
    if ! id "$SSH_USER" &>/dev/null; then
        useradd -m -s /bin/bash $SSH_USER
        echo "$SSH_USER:$SSH_PASSWORD" | chpasswd
        echo "AllowUsers $SSH_USER" >> /etc/ssh/sshd_config
    fi
fi

# 设置额外用户
if [ ! -z "$ADDITIONAL_USERS" ]; then
    IFS=',' read -ra USERS <<< "$ADDITIONAL_USERS"
    for USER_PASS in "${USERS[@]}"; do
        IFS=':' read -ra USER_INFO <<< "$USER_PASS"
        USERNAME="${USER_INFO[0]}"
        PASSWORD="${USER_INFO[1]}"
        
        if [ ! -z "$USERNAME" ] && [ ! -z "$PASSWORD" ]; then
            if ! id "$USERNAME" &>/dev/null; then
                useradd -m -s /bin/bash $USERNAME
                echo "$USERNAME:$PASSWORD" | chpasswd
            fi
        fi
    done
fi

# 更新 SSH 配置
CURRENT_ALLOW=$(grep "^AllowUsers" /etc/ssh/sshd_config | cut -d' ' -f2-)
if [ ! -z "$CURRENT_ALLOW" ]; then
    sed -i "s/^AllowUsers.*/AllowUsers $CURRENT_ALLOW/" /etc/ssh/sshd_config
fi

# 禁用 root 登录
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config
```

### 5. 安全最佳实践

1. **使用强密码**：
   ```bash
   # 生成随机密码
   openssl rand -base64 12
   ```

2. **SSH 密钥认证**：
   ```dockerfile
   # 在 Dockerfile 中设置 SSH 密钥
   RUN mkdir -p /home/ossapp/.ssh && \
       chmod 700 /home/ossapp/.ssh && \
       echo "ssh-rsa AAAAB3NzaC1yc2E..." > /home/ossapp/.ssh/authorized_keys && \
       chown -R ossapp:ossapp /home/ossapp/.ssh && \
       chmod 600 /home/ossapp/.ssh/authorized_keys
   ```

3. **限制用户权限**：
   ```dockerfile
   # 不给普通用户 sudo 权限
   RUN useradd -m -s /bin/bash limiteduser && \
       echo 'limiteduser:password' | chpasswd
   ```

4. **使用非标准端口**：
   ```dockerfile
   RUN sed -i 's/#Port 22/Port 2222/g' /etc/ssh/sshd_config
   EXPOSE 2222
   ```

这些配置示例提供了灵活的SSH用户管理方案，可以根据具体需求选择合适的方案。