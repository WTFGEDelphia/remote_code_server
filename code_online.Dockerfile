# 1. 使用 Ubuntu 25.10 作为基础镜像
FROM ubuntu:25.10

# 设置国内镜像源
RUN sed -Ei 's@https?://(archive|security).ubuntu.com@http://mirrors.tuna.tsinghua.edu.cn@g' \
    /etc/apt/sources.list.d/ubuntu.sources && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    openssh-server \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- 生成 SSH 主机密钥 ---
RUN ssh-keygen -A

# 设置 root 密码 (用于测试)
RUN echo 'root:password' | chpasswd

# 允许 root 用户通过密码 SSH 登录
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# --- SSH 服务配置 ---
RUN mkdir -p /var/run/sshd
EXPOSE 22

# 启动 SSH 服务 (以 root 身份运行)
CMD ["/usr/sbin/sshd", "-D"]
