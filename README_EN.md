# Remote Code Server Development Environment

A Docker-based containerized development environment that provides VS Code Remote development capabilities, supporting both Ubuntu standard and multi-stage build images.

- [**简体中文**](./README.md)
- [**English**](./README_EN.md)

## 🌟 Features

- **Containerized Development Environment** - Fully standardized development environment based on Docker
- **Dual Version Support** - Provides Ubuntu standard and multi-stage optimized versions
- **VS Code Integration** - Pre-installed VS Code Server with Remote-SSH development support
- **Node.js Environment** - Multiple Node.js versions managed through nvm
- **Ready to Use** - One-click startup of complete development environment
- **Proxy Friendly** - Built-in HTTP/HTTPS proxy configuration
- **Data Persistence** - Supports data mounting and persistent storage

## 📦 Project Structure

```
.
├── docker-compose.yml              # Docker compose configuration
├── quick-start.sh                  # Quick start script
├── ubuntu.Dockerfile               # Ubuntu standard Dockerfile
├── ubuntu.multistage.Dockerfile    # Ubuntu multi-stage Dockerfile
├── .dockerignore                   # Docker build ignore file
├── README.md                       # Project documentation (Chinese)
└── README_EN.md                    # Project documentation (English)
```

## 🚀 Quick Start

### Prerequisites

- Docker >= 20.10
- Docker Compose >= 1.29

### Starting Services

#### 1. Start Ubuntu Standard Version

```bash
./quick-start.sh ubuntu
```

#### 2. Start Ubuntu Multi-Stage Version

```bash
./quick-start.sh multistage
```

#### 3. View All Options

```bash
./quick-start.sh help
```

### Common Operations

```bash
# Start services
./quick-start.sh ubuntu      # Start Ubuntu standard version
./quick-start.sh multistage  # Start Ubuntu multi-stage version

# Stop and cleanup
./quick-start.sh stop        # Stop all containers
./quick-start.sh clean       # Clean all containers and images
./quick-start.sh clean-volumes  # Clean all data

# Status check
./quick-start.sh status      # Show container status
./quick-start.sh dirs        # Show mounted directory status
./quick-start.sh verify      # Verify all running services
```

## 🔌 Connecting to Development Environment

### SSH Connection

#### Ubuntu Standard Version
```
Host: localhost
Port: 2022
Username: ossapp
Password: ossapp
```

#### Ubuntu Multi-Stage Version
```
Host: localhost
Port: 2023
Username: ossapp
Password: ossapp
```

### VS Code Remote Connection

#### Ubuntu Standard Version
```
ssh://ossapp@localhost:2022
```

#### Ubuntu Multi-Stage Version
```
ssh://ossapp@localhost:2023
```

## 📋 Pre-installed Software

| Software | Version | Description |
|----------|---------|-------------|
| Ubuntu | 25.10 | Base operating system |
| VS Code Server | 7d842fb85a0275a4a8e4d7e040d2625abbf7f084 | VS Code remote development server |
| VS Code CLI | 7d842fb85a0275a4a8e4d7e040d2625abbf7f084 | Command-line tool |
| Node.js | Latest LTS | Managed via nvm |
| nvm | 0.40.3 | Node version manager |
| OpenSSH | Latest | SSH service |
| Git | Latest | Version control |

## ⚙️ Configuration

### Port Configuration

- **Ubuntu Standard Version**: 2022
- **Ubuntu Multi-Stage Version**: 2023

### Data Mounting

- **Ubuntu Standard Version**: `./ubuntu-wk-data` → `/home/ossapp/workspace`
- **Ubuntu Multi-Stage Version**: `./multistage-wk-data` → `/home/ossapp/workspace`

### Network Configuration

- Container Network: `dev-network` (bridge mode)
- Proxy Configuration: `HTTP_PROXY=http://172.20.44.28:7897`

## 🔧 Customization

### Modify Proxy Settings

Edit the `x-proxy-config` section in `docker-compose.yml`:

```yaml
x-proxy-config: &proxy-args
    args:
        - HTTP_PROXY=http://your-proxy:port
        - HTTPS_PROXY=http://your-proxy:port
        - NO_PROXY=localhost,127.0.0.1,
```

### Modify Ports

Edit port mapping in `docker-compose.yml`:

```yaml
ports:
    - "YOUR_PORT:2022"
```

### Customize User

Modify user configuration in Dockerfile:

```dockerfile
ARG USER_NAME="your_username"
```

## 🛠️ Development Workflow

1. **Start Environment**
   ```bash
   ./quick-start.sh ubuntu
   ```

2. **Connect to Container**
   ```bash
   ssh ossapp@localhost:2022
   ```

3. **Open Remote-SSH in VS Code**
   - Install Remote-SSH extension
   - Connect to `ssh://ossapp@localhost:2022`

4. **Start Development**
   - Your working directory is at `/home/ossapp/workspace`
   - All changes are persisted to the local mounted directory

5. **Stop Environment**
   ```bash
   ./quick-start.sh stop
   ```

## 🔍 Troubleshooting

### Container Fails to Start

1. Check Docker service status
   ```bash
   systemctl status docker
   ```

2. Check if port is already in use
   ```bash
   netstat -tulpn | grep 2022
   ```

3. Check container logs
   ```bash
   docker-compose logs dev-ubuntu
   ```

### SSH Connection Failed

1. Verify container status
   ```bash
   docker ps | grep dev-ubuntu
   ```

2. Restart container
   ```bash
   ./quick-start.sh stop
   ./quick-start.sh ubuntu
   ```

### Verify Services

Run verification script to check all service status:

```bash
./quick-start.sh verify
```

## 📚 Advanced Usage

### Run Multiple Environments in Parallel

You can start both standard and multi-stage versions simultaneously:

```bash
./quick-start.sh ubuntu
./quick-start.sh multistage
```

### Backup Data

```bash
# Backup mounted directories
tar -czf ubuntu-wk-data-backup.tar.gz ubuntu-wk-data/
```

### Reset Environment

```bash
# Complete cleanup and restart
./quick-start.sh clean-volumes
./quick-start.sh ubuntu
```

## 🤝 Contributing

Feel free to submit Issues and Pull Requests to improve this project.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Contact

For questions or suggestions, please contact:

- Submit an [Issue](https://github.com/WTFGEDelphia/remote_code_server/issues)
- Send email to: wtf5058@163.com

## 🙏 Acknowledgments

Thanks to the following open source projects:

- [Docker](https://www.docker.com/)
- [VS Code](https://code.visualstudio.com/)
- [nvm](https://github.com/nvm-sh/nvm)
- [Ubuntu](https://ubuntu.com/)

---

**Note**: Please change the default password after first connection to ensure security.
