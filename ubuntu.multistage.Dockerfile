# 多阶段构建版本
# 阶段 1: 构建阶段 - 安装依赖和工具
FROM ubuntu:25.10 AS builder

# 设置构建参数
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
ARG NVM_VERSION="0.40.3"
ARG VSCODE_COMMIT_ID="7d842fb85a0275a4a8e4d7e040d2625abbf7f084"

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    NO_PROXY=${NO_PROXY}

# 安装构建依赖
RUN sed -Ei 's@https?://(archive|security).ubuntu.com@http://mirrors.tuna.tsinghua.edu.cn@g' \
    /etc/apt/sources.list.d/ubuntu.sources && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 下载并解压 VS Code Server
RUN curl -Lk "https://vscode.download.prss.microsoft.com/dbazure/download/stable/${VSCODE_COMMIT_ID}/vscode-server-linux-x64.tar.gz" \
    --output /tmp/vscode-server.tar.gz && \
    tar -xzf /tmp/vscode-server.tar.gz -C /tmp/ && \
    mv /tmp/vscode-server-linux-x64 /tmp/server && \
    rm -f /tmp/vscode-server.tar.gz

RUN curl -Lk "https://vscode.download.prss.microsoft.com/dbazure/download/stable/${VSCODE_COMMIT_ID}/vscode_cli_alpine_x64_cli.tar.gz" \
    --output  /tmp/vscode_cli_alpine_x64_cli.tar.gz && \
    tar -xzf /tmp/vscode_cli_alpine_x64_cli.tar.gz -C /tmp/ && \
    mv /tmp/code /tmp/code-${VSCODE_COMMIT_ID} && \
    rm -f /tmp/vscode_cli_alpine_x64_cli.tar.gz

# 下载 nvm 安装脚本
RUN curl -Lk https://github.com/nvm-sh/nvm/archive/refs/tags/v${NVM_VERSION}.tar.gz \
    --output /tmp/nvm-${NVM_VERSION}.tar.gz && \
    tar -xzf /tmp/nvm-${NVM_VERSION}.tar.gz -C /tmp/ && \
    mv /tmp/nvm-${NVM_VERSION} /tmp/.nvm && \
    rm -f /tmp/nvm-${NVM_VERSION}.tar.gz

# 阶段 2: 运行时阶段 - 最小化最终镜像
FROM ubuntu:25.10 AS runtime

# 设置构建参数
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
ARG USER_NAME="ossapp"
ARG VSCODE_COMMIT_ID="7d842fb85a0275a4a8e4d7e040d2625abbf7f084"
ARG SSH_PORT=2022

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    NO_PROXY=${NO_PROXY} \
    NVM_DIR="/home/${USER_NAME}/.nvm" \
    CODE_SERVER_DIR="/home/${USER_NAME}/.vscode-server/cli/servers/Stable-${VSCODE_COMMIT_ID}" \
    PATH="/home/${USER_NAME}/.nvm/versions/node/v*/bin:$PATH"

# 安装运行时依赖
RUN sed -Ei 's@https?://(archive|security).ubuntu.com@http://mirrors.tuna.tsinghua.edu.cn@g' \
    /etc/apt/sources.list.d/ubuntu.sources && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    sudo \
    curl \
    libatomic1 \
    openssh-server \
    procps \
    bash \
    ca-certificates \
    && \
    # 直接覆盖时区配置（无需安装 tzdata）
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 创建用户和组
RUN groupadd -r ${USER_NAME} -g 1001 && \
    useradd -r -g ${USER_NAME} -u 1001 -m -s /bin/bash ${USER_NAME} && \
    usermod -aG sudo ${USER_NAME} && \
    echo 'ossapp:ossapp' | chpasswd && \
    echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 配置 SSH 服务
RUN mkdir -p /var/run/sshd && \
    sed -i "s/#Port 22/Port ${SSH_PORT}/g" /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config && \
    echo "AllowUsers ${USER_NAME}" >> /etc/ssh/sshd_config

# 从构建阶段复制 VS Code Server
COPY --from=builder /tmp/server ${CODE_SERVER_DIR}/server
COPY --from=builder /tmp/code-${VSCODE_COMMIT_ID} /home/${USER_NAME}/.vscode-server/
# 从构建阶段复制 nvm 安装脚本并安装
COPY --from=builder /tmp/.nvm ${NVM_DIR}

# 设置用户目录权限
RUN mkdir -p /home/${USER_NAME}/workspace && \
    chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}

# 安装最新版本的nodejs
RUN sudo -u ${USER_NAME} bash -c "echo 'export NVM_DIR="/home/${USER_NAME}/.nvm"' >> /home/${USER_NAME}/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'  \# This loads nvm >> /home/${USER_NAME}/.bashrc && \
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'  \# This loads nvm bash_completion >> /home/${USER_NAME}/.bashrc  && \
    source ${NVM_DIR}/nvm.sh && nvm install node && nvm use node && nvm alias default node"

# 暴露 SSH 端口
EXPOSE ${SSH_PORT}

# 添加健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD service ssh status || exit 1

# 启动 SSH 服务
CMD ["/usr/sbin/sshd", "-D"]
