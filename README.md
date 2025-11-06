# 远程代码服务器开发环境

一个基于Docker的容器化开发环境，提供VS Code Remote远程开发功能，支持Ubuntu标准版和多阶段构建版两种镜像。

- [**简体中文**](./README.md)
- [**English**](./README_EN.md)

## 🌟 项目特点

- **容器化开发环境** - 完全基于Docker的标准化开发环境
- **双版本支持** - 提供Ubuntu标准版和多阶段优化版
- **VS Code集成** - 预装VS Code Server，支持Remote-SSH开发
- **Node.js环境** - 通过nvm管理多个Node.js版本
- **即开即用** - 一键启动完整开发环境
- **代理友好** - 内置HTTP/HTTPS代理配置
- **数据持久化** - 支持数据挂载和持久化存储

## 📦 项目结构

```
.
├── docker-compose.yml              # Docker编排配置
├── quick-start.sh                  # 快速启动脚本
├── ubuntu.Dockerfile               # Ubuntu标准版Dockerfile
├── ubuntu.multistage.Dockerfile    # Ubuntu多阶段构建版Dockerfile
├── .dockerignore                   # Docker构建忽略文件
├── README.md                       # 项目说明文档（中文）
└── README_EN.md                    # 项目说明文档（英文）
```

## 🚀 快速开始

### 前置要求

- Docker >= 20.10
- Docker Compose >= 1.29

### 启动服务

#### 1. 启动Ubuntu标准版

```bash
./quick-start.sh ubuntu
```

#### 2. 启动Ubuntu多阶段版

```bash
./quick-start.sh multistage
```

#### 3. 查看所有选项

```bash
./quick-start.sh help
```

### 常用操作

```bash
# 启动服务
./quick-start.sh ubuntu      # 启动Ubuntu标准版
./quick-start.sh multistage  # 启动Ubuntu多阶段版

# 停止和清理
./quick-start.sh stop        # 停止所有容器
./quick-start.sh clean       # 清理所有容器和镜像
./quick-start.sh clean-volumes  # 清理所有数据

# 状态查看
./quick-start.sh status      # 显示容器状态
./quick-start.sh dirs        # 显示挂载目录状态
./quick-start.sh verify      # 验证所有运行中的服务
```

## 🔌 连接开发环境

### SSH连接

#### Ubuntu标准版
```
主机: localhost
端口: 2022
用户名: ossapp
密码: ossapp
```

#### Ubuntu多阶段版
```
主机: localhost
端口: 2023
用户名: ossapp
密码: ossapp
```

### VS Code Remote连接

#### Ubuntu标准版
```
ssh://ossapp@localhost:2022
```

#### Ubuntu多阶段版
```
ssh://ossapp@localhost:2023
```

## 📋 预装软件

| 软件 | 版本 | 说明 |
|------|------|------|
| Ubuntu | 25.10 | 基础操作系统 |
| VS Code Server | 7d842fb85a0275a4a8e4d7e040d2625abbf7f084 | VS Code远程开发服务器 |
| VS Code CLI | 7d842fb85a0275a4a8e4d7e040d2625abbf7f084 | 命令行工具 |
| Node.js | 最新LTS | 通过nvm管理 |
| nvm | 0.40.3 | Node版本管理器 |
| OpenSSH | 最新版 | SSH服务 |
| Git | 最新版 | 版本控制 |

## ⚙️ 配置说明

### 端口配置

- **Ubuntu标准版**: 2022
- **Ubuntu多阶段版**: 2023

### 数据挂载

- **Ubuntu标准版**: `./ubuntu-wk-data` → `/home/ossapp/workspace`
- **Ubuntu多阶段版**: `./multistage-wk-data` → `/home/ossapp/workspace`

### 网络配置

- 容器网络: `dev-network` (bridge模式)
- 代理配置: `HTTP_PROXY=http://172.20.44.28:7897`

## 🔧 自定义配置

### 修改代理设置

编辑 `docker-compose.yml` 文件中的 `x-proxy-config` 部分：

```yaml
x-proxy-config: &proxy-args
    args:
        - HTTP_PROXY=http://your-proxy:port
        - HTTPS_PROXY=http://your-proxy:port
        - NO_PROXY=localhost,127.0.0.1,
```

### 修改端口

在 `docker-compose.yml` 中修改端口映射：

```yaml
ports:
    - "YOUR_PORT:2022"
```

### 自定义用户

在Dockerfile中修改用户配置：

```dockerfile
ARG USER_NAME="your_username"
```

## 🛠️ 开发工作流

1. **启动环境**
   ```bash
   ./quick-start.sh ubuntu
   ```

2. **连接到容器**
   ```bash
   ssh ossapp@localhost:2022
   ```

3. **在VS Code中打开Remote-SSH**
   - 安装Remote-SSH扩展
   - 连接到 `ssh://ossapp@localhost:2022`

4. **开始开发**
   - 你的工作目录位于 `/home/ossapp/workspace`
   - 所有更改都会持久化到本地挂载目录

5. **停止环境**
   ```bash
   ./quick-start.sh stop
   ```

## 🔍 故障排除

### 容器无法启动

1. 检查Docker服务状态
   ```bash
   systemctl status docker
   ```

2. 检查端口是否被占用
   ```bash
   netstat -tulpn | grep 2022
   ```

3. 查看容器日志
   ```bash
   docker-compose logs dev-ubuntu
   ```

### SSH连接失败

1. 验证容器状态
   ```bash
   docker ps | grep dev-ubuntu
   ```

2. 重新启动容器
   ```bash
   ./quick-start.sh stop
   ./quick-start.sh ubuntu
   ```

### 验证服务

运行验证脚本检查所有服务状态：

```bash
./quick-start.sh verify
```

## 📚 高级用法

### 多环境并行运行

可以同时启动标准版和多阶段版：

```bash
./quick-start.sh ubuntu
./quick-start.sh multistage
```

### 备份数据

```bash
# 备份挂载目录
tar -czf ubuntu-wk-data-backup.tar.gz ubuntu-wk-data/
```

### 重置环境

```bash
# 完全清理并重新开始
./quick-start.sh clean-volumes
./quick-start.sh ubuntu
```

## 🤝 贡献指南

欢迎提交Issue和Pull Request来改进这个项目。

## 📄 许可证

本项目采用MIT许可证 - 详见 [LICENSE](LICENSE) 文件

## 👥 联系方式

如有问题或建议，请通过以下方式联系：

- 提交 [Issue](https://github.com/WTFGEDelphia/remote_code_server/issues)
- 发送邮件至: wtf5058@163.com

## 🙏 致谢

感谢以下开源项目：

- [Docker](https://www.docker.com/)
- [VS Code](https://code.visualstudio.com/)
- [nvm](https://github.com/nvm-sh/nvm)
- [Ubuntu](https://ubuntu.com/)

---

**注意**: 首次连接后请及时修改默认密码以确保安全。
