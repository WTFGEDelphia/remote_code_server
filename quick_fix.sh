#!/bin/bash

# SSH Docker 容器快速修复脚本

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

# 检查Docker是否可用
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装或不可用"
        return 1
    fi

    if ! docker info &> /dev/null; then
        print_error "Docker 服务未运行或权限不足"
        return 1
    fi

    print_success "Docker 环境正常"
    return 0
}

# 清理现有容器
cleanup_container() {
    print_info "清理现有容器..."

    if docker ps -a | grep -q ubuntu-ssh-container; then
        docker stop ubuntu-ssh-container 2>/dev/null || true
        docker rm ubuntu-ssh-container 2>/dev/null || true
        print_success "已清理现有容器"
    else
        print_info "没有找到现有容器"
    fi
}

# 重新构建镜像
rebuild_image() {
    print_info "重新构建 Docker 镜像..."

    if [ ! -f "Dockerfile" ]; then
        print_error "未找到 Dockerfile 文件"
        return 1
    fi

    # 检查Dockerfile是否包含必要的配置
    if ! grep -q "useradd -m -s /bin/bash ossapp" Dockerfile; then
        print_error "Dockerfile 中缺少 ossapp 用户配置"
        return 1
    fi

    docker build -t ubuntu-ssh:25.10 .

    if [ $? -eq 0 ]; then
        print_success "镜像构建成功"
        return 0
    else
        print_error "镜像构建失败"
        return 1
    fi
}

# 启动容器
start_container() {
    print_info "启动 SSH 容器..."

    # 检查端口2022是否被占用
    if netstat -tlnp 2>/dev/null | grep -q ":2022"; then
        print_warning "端口 2022 已被占用，尝试使用其他端口"
        PORT=4001
    else
        PORT=2022
    fi

    docker run -d -p ${PORT}:2022 \
        --name ubuntu-ssh-container \
        --restart unless-stopped \
        ubuntu-ssh:25.10

    if [ $? -eq 0 ]; then
        print_success "容器启动成功 (端口: ${PORT})"
        return 0
    else
        print_error "容器启动失败"
        return 1
    fi
}

# 验证容器状态
verify_container() {
    print_info "验证容器状态..."

    sleep 3  # 等待容器完全启动

    # 检查容器是否运行
    if ! docker ps | grep -q ubuntu-ssh-container; then
        print_error "容器未运行"
        print_info "容器日志:"
        docker logs ubuntu-ssh-container --tail 10
        return 1
    fi

    # 检查端口映射
    if ! docker port ubuntu-ssh-container | grep -q "2022"; then
        print_error "端口映射异常"
        return 1
    fi

    # 检查SSH进程
    if ! docker exec ubuntu-ssh-container ps aux | grep -q sshd; then
        print_error "SSH 进程未运行"
        return 1
    fi

    # 检查用户
    if ! docker exec ubuntu-ssh-container id ossapp &> /dev/null; then
        print_error "ossapp 用户不存在"
        return 1
    fi

    print_success "容器验证通过"
    return 0
}

# 测试SSH连接
test_ssh_connection() {
    print_info "测试 SSH 连接..."

    sleep 2  # 等待SSH服务完全启动

    # 获取实际端口
    PORT=$(docker port ubuntu-ssh-container | grep 2022 | cut -d' ' -f3 | cut -d':' -f2)

    # 尝试SSH连接
    if timeout 10 sshpass -p 'ossapp' ssh -o StrictHostKeyChecking=no \
                      -o ConnectTimeout=5 \
                      -o PasswordAuthentication=yes \
                      ossapp@localhost \
                      -p ${PORT} \
                      'echo "SSH连接测试成功"' 2>/dev/null; then
        print_success "SSH 连接测试成功！"
        return 0
    else
        print_warning "SSH 连接测试失败"
        print_info "尝试手动测试:"
        echo "ssh ossapp@localhost -p ${PORT}"
        echo "密码: ossapp"
        return 1
    fi
}

# 显示连接信息
show_connection_info() {
    PORT=$(docker port ubuntu-ssh-container | grep 2022 | cut -d' ' -f3 | cut -d':' -f2)

    echo
    echo "=========================================="
    echo "         SSH 容器连接信息"
    echo "=========================================="
    echo "容器名称:     ubuntu-ssh-container"
    echo "SSH 端口:     ${PORT}"
    echo "连接命令:     ssh ossapp@localhost -p ${PORT}"
    echo "用户名:       ossapp"
    echo "密码:         ossapp"
    echo "容器状态:     $(docker ps | grep ubuntu-ssh-container | awk '{print $NF}')"
    echo "=========================================="
    echo
    echo "有用命令:"
    echo "  查看日志:    docker logs -f ubuntu-ssh-container"
    echo "  进入容器:    docker exec -it ubuntu-ssh-container /bin/bash"
    echo "  停止容器:    docker stop ubuntu-ssh-container"
    echo "  删除容器:    docker rm ubuntu-ssh-container"
    echo
}

# 修复SSH服务（如果需要）
fix_ssh_service() {
    print_info "检查并修复 SSH 服务..."

    # 进入容器并修复SSH配置
    docker exec ubuntu-ssh-container /bin/bash -c "
        # 确保SSH服务正在运行
        if ! pgrep sshd > /dev/null; then
            echo '启动 SSH 服务...'
            /usr/sbin/sshd
        fi

        # 检查SSH配置
        if ! grep -q 'Port 2022' /etc/ssh/sshd_config; then
            echo '修复 SSH 端口配置...'
            sed -i 's/#Port 22/Port 2022/g' /etc/ssh/sshd_config
            service ssh restart
        fi

        # 确保用户可以登录
        if ! grep -q 'AllowUsers ossapp' /etc/ssh/sshd_config; then
            echo '添加用户访问控制...'
            echo 'AllowUsers ossapp' >> /etc/ssh/sshd_config
            service ssh restart
        fi

        # 确保root登录被禁用
        sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config
        service ssh restart
    "

    print_success "SSH 服务修复完成"
}

# 主修复流程
main_fix() {
    echo "=========================================="
    echo "      SSH Docker 容器快速修复"
    echo "=========================================="
    echo

    # 检查Docker环境
    if ! check_docker; then
        print_error "Docker 环境不可用，请先安装并启动 Docker"
        exit 1
    fi

    # 执行修复步骤
    cleanup_container
    echo

    if ! rebuild_image; then
        print_error "镜像构建失败，请检查 Dockerfile"
        exit 1
    fi
    echo

    if ! start_container; then
        print_error "容器启动失败"
        exit 1
    fi
    echo

    if ! verify_container; then
        print_warning "容器验证失败，尝试修复 SSH 服务..."
        fix_ssh_service
        echo

        if ! verify_container; then
            print_error "容器修复失败，请查看日志"
            docker logs ubuntu-ssh-container --tail 20
            exit 1
        fi
    fi
    echo

    # 测试连接
    test_ssh_connection
    echo

    # 显示连接信息
    show_connection_info

    print_success "修复完成！"
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [命令]"
    echo
    echo "命令:"
    echo "  fix         执行完整修复流程 (默认)"
    echo "  cleanup     仅清理容器"
    echo "  rebuild     仅重新构建镜像"
    echo "  start       仅启动容器"
    echo "  verify      仅验证容器状态"
    echo "  test        仅测试 SSH 连接"
    echo "  help        显示此帮助信息"
    echo
    echo "示例:"
    echo "  $0          # 执行完整修复"
    echo "  $0 rebuild  # 仅重新构建镜像"
    echo "  $0 test     # 仅测试连接"
}

# 主函数
main() {
    case "${1:-fix}" in
        "fix")
            main_fix
            ;;
        "cleanup")
            cleanup_container
            ;;
        "rebuild")
            rebuild_image
            ;;
        "start")
            start_container
            ;;
        "verify")
            verify_container
            ;;
        "test")
            test_ssh_connection
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
