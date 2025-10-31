# 1. 使用 Ubuntu 25.10 作为基础镜像
FROM ubuntu:25.10

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

RUN ssh-keygen -A
# 确保 root 用户拥有 /etc/ssh 目录和文件
RUN chown -R root:root /etc/ssh/ && chmod -R 755 /etc/ssh/

# --- VS Code Server 安装配置 ---

# 定义 VS Code Server 的 commit ID 和版本
# 你可以根据需要修改这个 commit_id，或者通过 ARG 参数在构建时传入
ARG VSCODE_COMMIT_ID="7d842fb85a0275a4a8e4d7e040d2625abbf7f084"

# 设置 VS Code Server 的下载 URL (使用新版下载链接)
# 根据 download.md，使用 vscode_cli_alpine_x64_cli.tar.gz 以便运行 'code tunnel'
ENV VSCODE_CLI_URL="https://vscode.download.prss.microsoft.com/dbazure/download/stable/${VSCODE_COMMIT_ID}/vscode_cli_alpine_x64_cli.tar.gz"
ENV VSCODE_SERVER_URL="https://vscode.download.prss.microsoft.com/dbazure/download/stable/${VSCODE_COMMIT_ID}/vscode-server-linux-x64.tar.gz"

# 创建 vscode 用户和组
# USERGROUP_ID 和 USER_ID 可以指定，或者让系统自动分配
# 这里指定 GID=1001, UID=1001
RUN groupadd --gid 1001 vscode && \
    useradd --uid 1001 --gid 1001 --create-home --shell /bin/bash vscode

# 创建 VS Code Server 所需的目录结构
# 这里的目录结构是参考 download.md 新版要求的
RUN mkdir -p /home/vscode/.vscode-server/cli/servers/Stable-${VSCODE_COMMIT_ID}/ && \
    chown -R vscode:vscode /home/vscode

RUN curl -Lk ${VSCODE_SERVER_URL} --output /tmp/vscode-server-linux-x64.tar.gz && \
    tar -xzf /tmp/vscode-server-linux-x64.tar.gz -C \
    /home/vscode/.vscode-server/cli/servers/Stable-${VSCODE_COMMIT_ID}/ && \
    mv /home/vscode/.vscode-server/cli/servers/Stable-${VSCODE_COMMIT_ID}/vscode-server-linux-x64 \
    /home/vscode/.vscode-server/cli/servers/Stable-${VSCODE_COMMIT_ID}/server && \
    rm -f /tmp/vscode-server-linux-x64.tar.gz

RUN curl -Lk ${VSCODE_CLI_URL} --output /tmp/vscode_cli_alpine_x64_cli.tar.gz && \
    tar -xzf /tmp/vscode_cli_alpine_x64_cli.tar.gz -C \
    /home/vscode/.vscode-server/ && \
    mv /home/vscode/.vscode-server/code \
    /home/vscode/.vscode-server/code-${VSCODE_COMMIT_ID} && \
    rm -f /tmp/vscode_cli_alpine_x64_cli.tar.gz

# 确保 VS Code Server 的所有者是 vscode 用户
RUN chown -R vscode:vscode /home/vscode/.vscode-server

# 设置 root 密码 (再次强调：仅用于测试，生产环境请用 SSH 密钥)
RUN echo 'root:password' | chpasswd

# 设置 vscode 用户的密码 (仅用于测试，生产环境请用 SSH 密钥)
RUN echo 'vscode:password' | chpasswd

# 允许 root 用户通过密码 SSH 登录
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# USER vscode

# --- SSH 服务配置 ---
RUN mkdir -p /var/run/sshd

# 设置工作目录为 VS Code Server 的安装目录
# 容器启动后直接进入 VS Code Server 的工作模式，可以设置这里
WORKDIR /home/vscode

# 暴露 SSH 端口
EXPOSE 22

# 启动 SSH 服务
# 使用 exec 形式，这样 sshd 成为主进程 PID 1
CMD ["/usr/sbin/sshd", "-D"]

USER vscode
