# 基于 Docker 的 VS Code Remote SSH 开发环境

本项目提供了一个全面的解决方案，用于在 Docker 容器中搭建 VS Code 开发环境，并通过 Remote-SSH 扩展进行访问。它同时提供了在线和离线两种设置方法，以适应不同的网络条件。

## 功能特性

-   **Docker化开发**: 将您的开发环境封装在一个可移植、可复现的 Docker 容器中。
-   **无缝的 VS Code 集成**: 使用您本地的 VS Code 实例在容器内进行开发，提供原生且丰富的用户体验。
-   **在线模式**: 在构建镜像时动态下载 VS Code Server。适用于拥有稳定互联网连接的环境。
-   **离线模式**: 通过嵌入预先下载的 VS Code Server 来构建镜像，非常适合在无网络或网络受限的环境中使用。
-   **简化管理**: 使用 Docker Compose 轻松管理容器的生命周期、端口和数据卷。
-   **可定制**: 您可以轻松修改提供的 Dockerfile，以包含您特定项目所需的其他工具和依赖项。

## 1. 系统要求

在开始之前，请确保您的本地计算机上已安装以下软件：

-   **Docker**: 用于构建和运行镜像的容器化平台。
-   **Docker Compose**: 用于定义和运行多容器 Docker 应用程序的工具。
-   **Visual Studio Code**: 您的本地代码编辑器。
-   **VS Code 的 Remote - SSH 扩展**: 这是实现远程开发能力的核心组件。您可以直接从 VS Code Marketplace 安装它。
    1.  打开 VS Code。
    2.  进入扩展视图 (`Ctrl+Shift+X`)。
    3.  搜索 `Remote - SSH`。
    4.  点击“安装”。
-   **OpenSSH 客户端**: 大多数操作系统 (Linux, macOS, Windows 10/11) 都已预装。

## 2. 如何使用

### 步骤 1: 构建 Docker 镜像

您可以根据网络情况选择构建“在线”或“离线”镜像。

-   **在线构建**: 此版本将在镜像构建过程中下载 VS Code server。
    ```bash
    docker build -f code_online.Dockerfile -t remote_code_server:online .
    ```

-   **离线构建**: 此版本使用预先下载的 VS Code server。`Dockerfile` 和 `code_offline.Dockerfile` 均为此配置。
    ```bash
    docker build -f code_offline.Dockerfile -t remote_code_server:offline .
    ```

### 步骤 2: 运行容器

使用相应的 Docker Compose 文件在后台启动容器。

-   **运行在线容器**:
    ```bash
    docker-compose -f code_online.docker-compose.yml up -d
    ```

-   **运行离线容器**:
    ```bash
    docker-compose -f code_offline.docker-compose.yml up -d
    ```

这将会启动一个名为 `container_code_online` 或 `container_code_offline` 的容器，并将您本地机器的 `2222` 端口映射到容器内的 `22` 端口。

### 步骤 3: 配置 SSH 连接

为了让 VS Code 能够顺利连接，您需要在本地 SSH 配置文件中添加一个条目。

1.  打开您的 SSH 配置文件，通常位于 Linux/macOS 的 `~/.ssh/config` 或 Windows 的 `C:\Users\<您的用户名>\.ssh\config`。
2.  添加以下配置块：

    ```ssh-config
    Host vscode-docker-dev
        HostName localhost
        User root
        Port 2222
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
    ```

    -   **Host**: 连接的别名 (例如, `vscode-docker-dev`)。
    -   **HostName**: `localhost`，因为端口已映射到您的本地机器。
    -   **User**: 容器内的用户。提供的 Dockerfile 设置了 `root` 和 `vscode` 用户，密码均为 `password`。对于初始设置，使用 `root` 很方便。
    -   **Port**: 您在 `docker-compose.yml` 文件中映射的主机端口 (`2222`)。
    -   添加 `StrictHostKeyChecking` 和 `UserKnownHostsFile` 是为了方便起见，避免在容器重建后出现主机密钥错误。

### 步骤 4: 使用 VS Code 连接

1.  打开 VS Code。
2.  点击窗口左下角的绿色“远程窗口”按钮。
3.  从下拉菜单中选择 **"Connect to Host..."** (连接到主机...)。
4.  选择您在上一步中配置的主机 (例如, `vscode-docker-dev`)。
5.  一个新的 VS Code 窗口将会打开，并提示您输入密码。输入 `password`。
6.  您现在已经连接成功！新窗口正运行在 Docker 容器中。您可以直接在容器化环境中打开文件夹、使用集成终端以及安装扩展。

## 安全最佳实践

默认配置旨在方便使用和测试。对于更安全或类似生产的环境，请考虑以下改进：

-   **使用 SSH 密钥**: 修改 `Dockerfile` 和 `docker-compose.yml`，使用基于 SSH 密钥的身份验证代替密码。您可以通过将您的 `~/.ssh/authorized_keys` 文件挂载到容器中来实现。
-   **避免使用 Root 用户**: 在 `Dockerfile` 中创建一个非 root 用户（如果需要，可以赋予 `sudo` 权限），并使用该用户进行 SSH 连接。提供的 `code_offline.Dockerfile` 已经创建了一个 `vscode` 用户。
-   **限制端口暴露**: 如果可能，不要将 SSH 端口暴露到公共互联网。如果您只在本地访问，请将其绑定到 `127.0.0.1`。