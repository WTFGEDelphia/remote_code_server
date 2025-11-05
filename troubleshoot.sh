#!/bin/bash

# SSH 连接故障排除脚本

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

# 检查容器状态
check_container_status() {
    print_info "检查容器状态..."

    if docker ps | grep -q ubuntu-ssh-container; then
        print_success "✓ 容器正在运行"
        return 0
    else
        print_error "✗ 容器未运行"
        return 1
    fi
}

# 检查端口映射
check_port_mapping() {
    print_info "检查端口映射..."

    if docker port ubuntu-ssh-container | grep -q "2022"; then
        print_success "✓ 端口 2022 已正确映射"
        docker port ubuntu-ssh-container
        return 0
    else
        print_error "✗ 端口映射异常"
        return 1
    fi
}

# 检查容器日志
check_container_logs() {
    print_info "检查容器日志..."

    if docker logs ubuntu-ssh-container 2>&1 | grep -q "sshd"; then
        print_success "✓ SSH 服务正在运行"
        echo "最近 5 行日志:"
        docker logs ubuntu-ssh-container --tail 5
        return 0
    else
        print_error "✗ SSH 服务可能未正常启动"
        echo "完整日志:"
        docker logs ubuntu-ssh-container
        return 1
    fi
}

# 检查SSH进程
check_ssh_process() {
    print_info "检查 SSH 进程..."

    if docker exec ubuntu-ssh-container ps aux | grep -q "sshd"; then
        print_success "✓ SSH 进程正在运行"
        docker exec ubuntu-ssh-container ps aux | grep sshd
        return 0
    else
        print_error "✗ SSH 进程未找到"
        return 1
    fi
}

# 检查SSH配置文件
check_ssh_config() {
    print_info "检查 SSH 配置..."

    if docker exec ubuntu-ssh-container cat /etc/ssh/sshd_config | grep -q "Port 2022"; then
        print_success "✓ SSH 端口配置正确 (2022)"
    else
        print_error "✗ SSH 端口配置异常"
    fi

    if docker exec ubuntu-ssh-container cat /etc/ssh/sshd_config | grep -q "AllowUsers ossapp"; then
        print_success "✓ 用户访问控制配置正确"
    else
        print_warning "✗ 用户访问控制配置可能有问题"
    fi
}

# 检查用户是否存在
check_user() {
    print_info "检查 ossapp 用户..."

    if docker exec ubuntu-ssh-container id ossapp > /dev/null 2>&1; then
        print_success "✓ ossapp 用户存在"
        docker exec ubuntu-ssh-container id ossapp
        return 0
    else
        print_error "✗ ossapp 用户不存在"
        return 1
    fi
}

# 检查网络连接
check_network() {
    print_info "检查网络连接..."

    # 检查本地端口是否监听
    if netstat -tlnp 2>/dev/null | grep -q ":2022"; then
        print_success "✓ 端口 2022 正在监听"
    else
        print_warning "✗ 端口 2022 未监听"
    fi

    # 测试端口连通性
    if timeout 5 bash -c "echo > /dev/tcp/localhost/2022" 2>/dev/null; then
        print_success "✓ 端口 2022 连通性正常"
    else
        print_error "✗ 端口 2022 连通性异常"
    fi
}

# 尝试手动SSH连接
test_manual_ssh() {
    print_info "尝试手动 SSH 连接..."

    # 尝试使用密码连接
    if timeout 10 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o PasswordAuthentication=yes ossapp@localhost -p 2022 'echo "SSH 连接成功"' 2>/dev/null; then
        print_success "✓ SSH 连接成功"
        return 0
    else
        print_error "✗ SSH 连接失败"
        print_info "尝试使用 telnet 测试..."

        if timeout 5 telnet localhost 2022 2>/dev/null; then
            print_success "✓ 端口连通，但SSH认证失败"
            print_info "可能原因：密码错误或SSH配置问题"
        else
            print_error "✗ 端口连通失败"
        fi
        return 1
    fi
}

# 修复建议
provide_fix_suggestions() {
    print_info "提供修复建议..."
    echo
    echo "=========================================="
    echo "           修复建议"
    echo "=========================================="
    echo
    echo "1. 重新构建和运行容器:"
    echo "   docker stop ubuntu-ssh-container 2>/dev/null || true"
    echo "   docker rm ubuntu-ssh-container 2>/dev/null || true"
    echo "   docker build -t ubuntu-ssh:25.10 ."
    echo "   docker run -d -p 2022:2022 --name ubuntu-ssh-container ubuntu-ssh:25.10"
    echo
    echo "2. 检查容器内部状态:"
    echo "   docker exec -it ubuntu-ssh-container /bin/bash"
    echo "   # 在容器内执行:"
    echo "   ps aux | grep sshd"
    echo "   cat /etc/ssh/sshd_config | grep -E 'Port|PermitRootLogin|AllowUsers'"
    echo "   service ssh status"
    echo
    echo "3. 手动启动 SSH 服务:"
    echo "   docker exec ubuntu-ssh-container /usr/sbin/sshd -t"
    echo "   docker exec -d ubuntu-ssh-container /usr/sbin/sshd"
    echo
    echo "4. 检查防火墙设置:"
    echo "   sudo ufw status"
    echo "   sudo iptables -L"
    echo
    echo "5. 使用不同方式测试连接:"
    echo "   ssh -v ossapp@localhost -p 2022"
    echo "   nc -zv localhost 2022"
    echo "   telnet localhost 2022"
    echo
}

# 主诊断函数
main_diagnosis() {
    echo "=========================================="
    echo "      SSH 连接故障排除诊断"
    echo "=========================================="
    echo

    # 检查容器是否存在
    if ! docker ps -a | grep -q ubuntu-ssh-container; then
        print_error "容器 'ubuntu-ssh-container' 不存在"
        print_info "请先运行: docker run -d -p 2022:2022 --name ubuntu-ssh-container ubuntu-ssh:25.10"
        exit 1
    fi

    # 等待容器启动
    print_info "等待容器完全启动..."
    sleep 3

    # 执行各项检查
    local checks_passed=0
    local total_checks=6

    if check_container_status; then ((checks_passed++)); fi
    echo

    if check_port_mapping; then ((checks_passed++)); fi
    echo

    if check_container_logs; then ((checks_passed++)); fi
    echo

    if check_ssh_process; then ((checks_passed++)); fi
    echo

    if check_ssh_config; then ((checks_passed++)); fi
    echo

    if check_user; then ((checks_passed++)); fi
    echo

    check_network
    echo

    # 尝试SSH连接测试
    test_manual_ssh
    echo

    # 显示诊断结果
    echo "=========================================="
    echo "           诊断结果"
    echo "=========================================="
    echo "通过检查: $checks_passed/$total_checks"
    echo

    if [ $checks_passed -eq $total_checks ]; then
        print_success "所有基础检查都通过了，SSH应该可以正常工作"
        print_info "如果仍有问题，请检查网络或尝试重启容器"
    else
        print_warning "部分检查未通过，建议查看上述错误信息"
        provide_fix_suggestions
    fi
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [命令]"
    echo
    echo "命令:"
    echo "  diagnose    执行完整诊断 (默认)"
    echo "  container   检查容器状态"
    echo "  port        检查端口映射"
    echo "  logs        检查容器日志"
    echo "  process     检查 SSH 进程"
    echo "  config      检查 SSH 配置"
    echo "  user        检查用户"
    echo "  network     检查网络"
    echo "  ssh         测试 SSH 连接"
    echo "  fix         显示修复建议"
    echo "  help        显示此帮助信息"
}

# 主函数
main() {
    case "${1:-diagnose}" in
        "diagnose")
            main_diagnosis
            ;;
        "container")
            check_container_status
            ;;
        "port")
            check_port_mapping
            ;;
        "logs")
            check_container_logs
            ;;
        "process")
            check_ssh_process
            ;;
        "config")
            check_ssh_config
            ;;
        "user")
            check_user
            ;;
        "network")
            check_network
            ;;
        "ssh")
            test_manual_ssh
            ;;
        "fix")
            provide_fix_suggestions
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
