# 使用 Ubuntu 25.10 作为基础镜像
FROM ubuntu:25.10

# 设置环境变量避免交互式安装
ENV DEBIAN_FRONTEND=noninteractive
# 避免时区配置提示
ENV TZ=Asia/Shanghai
# 避免语言设置提示
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# 设置国内镜像源以加速下载，并安装必要的软件包
# RUN sed -Ei 's@https?://(archive|security).ubuntu.com@http://mirrors.aliyun.com@g' \
RUN sed -Ei 's@https?://(archive|security).ubuntu.com@http://mirrors.tuna.tsinghua.edu.cn@g' \
    /etc/apt/sources.list.d/ubuntu.sources && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    openssh-server \
    git \
    curl \
    wget \
    gnupg \
    ca-certificates \
    procps \
    unzip \
    tar \
    # Alpine CLI 可能依赖一些 Alpine Linux 的库，但通常在 Debian/Ubuntu 上也能运行
    # 如果遇到问题，可以考虑下载 non-alpine 的 CLI 版本
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 创建 SSH 目录
RUN mkdir -p /var/run/sshd

# --- VS Code Server 安装配置 ---

# 定义 VS Code Server 的 commit ID 和版本
# 你可以根据需要修改这个 commit_id，或者通过 ARG 参数在构建时传入
ARG VSCODE_COMMIT_ID="7d842fb85a0275a4a8e4d7e040d2625abbf7f084"

# 设置 VS Code Server 的下载 URL (使用新版下载链接)
ENV VSCODE_CLI_URL="https://vscode.download.prss.microsoft.com/dbazure/download/stable/${VSCODE_COMMIT_ID}/vscode_cli_alpine_x64_cli.tar.gz"
ENV VSCODE_SERVER_URL="https://vscode.download.prss.microsoft.com/dbazure/download/stable/${VSCODE_COMMIT_ID}/vscode-server-linux-x64.tar.gz"

# 创建 ossapp 用户
RUN useradd -m -s /bin/bash ossapp && \
    # 设置 ossapp 用户密码为 'ossapp'
    echo 'ossapp:ossapp' | chpasswd && \
    # 将 ossapp 用户添加到 sudo 组（可选）
    usermod -aG sudo ossapp

# 创建 VS Code Server 所需的目录结构
# 这里的目录结构是参考 download.md 新版要求的
RUN mkdir -p /home/ossapp/.vscode-server/cli/servers/Stable-${VSCODE_COMMIT_ID}/

RUN curl -Lk ${VSCODE_SERVER_URL} --output /tmp/vscode-server-linux-x64.tar.gz && \
    tar -xzf /tmp/vscode-server-linux-x64.tar.gz -C \
    /home/ossapp/.vscode-server/cli/servers/Stable-${VSCODE_COMMIT_ID}/ && \
    mv /home/ossapp/.vscode-server/cli/servers/Stable-${VSCODE_COMMIT_ID}/vscode-server-linux-x64 \
    /home/ossapp/.vscode-server/cli/servers/Stable-${VSCODE_COMMIT_ID}/server && \
    rm -f /tmp/vscode-server-linux-x64.tar.gz

RUN curl -Lk ${VSCODE_CLI_URL} --output /tmp/vscode_cli_alpine_x64_cli.tar.gz && \
    tar -xzf /tmp/vscode_cli_alpine_x64_cli.tar.gz -C \
    /home/ossapp/.vscode-server/ && \
    mv /home/ossapp/.vscode-server/code \
    /home/ossapp/.vscode-server/code-${VSCODE_COMMIT_ID} && \
    rm -f /tmp/vscode_cli_alpine_x64_cli.tar.gz

# 设置 root 密码 (再次强调：仅用于测试，生产环境请用 SSH 密钥)
RUN echo 'root:password' | chpasswd

# 配置 SSH 服务监听 2022 端口
RUN sed -i 's/#Port 22/Port 2022/g' /etc/ssh/sshd_config && \
    # 禁用 root 用户登录以提高安全性
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config && \
    # 确保允许 ossapp 用户登录
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config && \
    # 添加 AllowUsers 规则确保只允许特定用户
    echo "AllowUsers ossapp" >> /etc/ssh/sshd_config

RUN chown -R ossapp:ossapp /home/ossapp
# 暴露 SSH 端口
EXPOSE 2022

# 启动 SSH 服务
CMD ["/usr/sbin/sshd", "-D"]
