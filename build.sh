#!/bin/bash

# SSH Docker 容器构建和测试脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 Docker 是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    print_success "Docker 已安装"
}

# 构建镜像
build_image() {
    print_info "构建 Docker 镜像..."
    docker build -t ubuntu-ssh:25.10 .
    if [ $? -eq 0 ]; then
        print_success "镜像构建成功"
    else
        print_error "镜像构建失败"
        exit 1
    fi
}

# 停止并删除现有容器
cleanup_container() {
    if docker ps -a | grep -q ubuntu-ssh-container; then
        print_info "停止并删除现有容器..."
        docker stop ubuntu-ssh-container 2>/dev/null || true
        docker rm ubuntu-ssh-container 2>/dev/null || true
    fi
}

# 运行容器
run_container() {
    print_info "启动 SSH 容器..."
    docker run -d -p 2022:2022 --name ubuntu-ssh-container ubuntu-ssh:25.10
    if [ $? -eq 0 ]; then
        print_success "容器启动成功"
    else
        print_error "容器启动失败"
        exit 1
    fi
}

# 测试 SSH 连接
test_ssh() {
    print_info "等待 SSH 服务启动..."
    sleep 5

    # 检查容器是否运行
    if ! docker ps | grep -q ubuntu-ssh-container; then
        print_error "容器未运行，无法进行 SSH 测试"
        return 1
    fi

    # 检查端口映射
    if ! docker port ubuntu-ssh-container | grep -q "2022"; then
        print_error "端口 2022 未正确映射"
        return 1
    fi

    # 检查 SSH 进程
    if ! docker exec ubuntu-ssh-container ps aux | grep -q sshd; then
        print_error "SSH 进程未运行"
        print_info "尝试启动 SSH 服务..."
        docker exec ubuntu-ssh-container /usr/sbin/sshd
        sleep 3
    fi

    # 检查用户
    if ! docker exec ubuntu-ssh-container id ossapp &> /dev/null; then
        print_error "ossapp 用户不存在"
        return 1
    fi

    print_info "测试 SSH 连接..."

    # 尝试多次连接
    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        print_info "尝试连接 (第 $attempt 次)..."

        if timeout 10 sshpass -p 'ossapp' ssh -o StrictHostKeyChecking=no \
            -o ConnectTimeout=5 \
            -o PasswordAuthentication=yes \
            ossapp@localhost \
            -p 2022 \
            'echo "SSH 连接测试成功"' 2>/dev/null; then
            print_success "SSH 连接测试成功"
            return 0
        else
            if [ $attempt -lt $max_attempts ]; then
                print_warning "连接失败，3秒后重试..."
                sleep 3
            fi
        fi

        ((attempt++))
    done

    print_error "SSH 连接测试失败"
    print_info "故障排除建议:"
    echo "1. 查看容器日志: docker logs ubuntu-ssh-container"
    echo "2. 检查容器状态: docker ps | grep ubuntu-ssh-container"
    echo "3. 检查端口映射: docker port ubuntu-ssh-container"
    echo "4. 进入容器检查: docker exec -it ubuntu-ssh-container /bin/bash"
    echo "5. 运行诊断脚本: bash troubleshoot.sh diagnose"
    echo "6. 运行快速修复: bash quick_fix.sh fix"

    return 1
}

# 显示容器信息
show_info() {
    print_info "容器信息:"
    docker ps | grep ubuntu-ssh-container || print_warning "容器未运行"

    print_info "容器日志:"
    docker logs ubuntu-ssh-container --tail 10

    print_info "连接信息:"
    echo "SSH 连接命令: ssh ossapp@localhost -p 2022"
    echo "默认密码: ossapp"
}

# 清理函数
cleanup() {
    print_info "清理容器..."
    docker stop ubuntu-ssh-container 2>/dev/null || true
    docker rm ubuntu-ssh-container 2>/dev/null || true
    print_success "清理完成"
}

# 主函数
main() {
    echo "=========================================="
    echo "       SSH Docker 容器构建脚本"
    echo "=========================================="
    echo

    case "${1:-build}" in
        "build")
            check_docker
            build_image
            cleanup_container
            run_container
            test_ssh
            show_info
            ;;
        "run")
            check_docker
            cleanup_container
            run_container
            test_ssh
            show_info
            ;;
        "stop")
            cleanup
            ;;
        "logs")
            docker logs -f ubuntu-ssh-container
            ;;
        "shell")
            docker exec -it ubuntu-ssh-container /bin/bash
            ;;
        "test")
            test_ssh
            ;;
        "diagnose")
            if [ -f "troubleshoot.sh" ]; then
                bash troubleshoot.sh diagnose
            else
                print_error "troubleshoot.sh 脚本未找到"
                exit 1
            fi
            ;;
        "fix")
            if [ -f "quick_fix.sh" ]; then
                bash quick_fix.sh fix
            else
                print_error "quick_fix.sh 脚本未找到"
                exit 1
            fi
            ;;
        "help"|"-h"|"--help")
            echo "用法: $0 [命令]"
            echo
            echo "命令:"
            echo "  build       构建 Docker 镜像 (默认)"
            echo "  run         运行容器"
            echo "  stop        停止并删除容器"
            echo "  logs        查看容器日志"
            echo "  shell       进入容器 shell"
            echo "  test        测试 SSH 连接"
            echo "  diagnose    诊断容器问题"
            echo "  fix         快速修复 SSH 问题"
            echo "  help        显示此帮助信息"
            ;;
        *)
            print_error "未知命令: $1"
            echo "使用 '$0 help' 查看可用命令"
            exit 1
            ;;
    esac
}

# 捕获 Ctrl+C 信号
trap cleanup EXIT

main "$@"
