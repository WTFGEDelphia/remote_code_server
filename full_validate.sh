#!/bin/bash

# SSH Docker 容器配置验证和测试脚本

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

# 验证Dockerfile配置
validate_dockerfile() {
    print_info "验证 Dockerfile 配置..."

    local errors=0

    # 检查基础镜像
    if grep -q "FROM ubuntu:25.10" Dockerfile; then
        print_success "✓ 基础镜像配置正确"
    else
        print_error "✗ 基础镜像配置错误"
        ((errors++))
    fi

    # 检查非交互环境变量
    if grep -q "ENV DEBIAN_FRONTEND=noninteractive" Dockerfile; then
        print_success "✓ 非交互环境变量配置正确"
    else
        print_warning "✗ 缺少非交互环境变量"
    fi

    # 检查SSH安装
    if grep -q "openssh-server" Dockerfile; then
        print_success "✓ OpenSSH Server 安装配置正确"
    else
        print_error "✗ OpenSSH Server 安装配置缺失"
        ((errors++))
    fi

    # 检查ossapp用户创建
    if grep -q "useradd -m -s /bin/bash ossapp" Dockerfile; then
        print_success "✓ ossapp 用户创建配置正确"
    else
        print_error "✗ ossapp 用户创建配置缺失"
        ((errors++))
    fi

    # 检查用户密码设置
    if grep -q "echo 'ossapp:ossapp' | chpasswd" Dockerfile; then
        print_success "✓ 用户密码设置配置正确"
    else
        print_error "✗ 用户密码设置配置缺失"
        ((errors++))
    fi

    # 检查SSH端口配置
    if grep -q "Port 2022" Dockerfile; then
        print_success "✓ SSH 端口配置正确 (2022)"
    else
        print_error "✗ SSH 端口配置错误"
        ((errors++))
    fi

    # 检查root登录禁用
    if grep -q "PermitRootLogin no" Dockerfile; then
        print_success "✓ root 用户登录已禁用"
    else
        print_warning "✗ root 用户登录未明确禁用"
    fi

    # 检查用户访问控制
    if grep -q "AllowUsers ossapp" Dockerfile; then
        print_success "✓ SSH 用户访问控制配置正确"
    else
        print_warning "✗ SSH 用户访问控制配置缺失"
    fi

    # 检查用户目录权限
    if grep -q "chown -R ossapp:ossapp /home/ossapp" Dockerfile; then
        print_success "✓ 用户目录权限设置正确"
    else
        print_warning "✗ 用户目录权限设置缺失"
    fi

    # 检查端口暴露
    if grep -q "EXPOSE 2022" Dockerfile; then
        print_success "✓ 端口暴露配置正确"
    else
        print_error "✗ 端口暴露配置缺失"
        ((errors++))
    fi

    return $errors
}

# 验证文档文件
validate_documentation() {
    print_info "验证文档文件..."

    local errors=0

    # 检查README.md
    if [ -f "README.md" ]; then
        if grep -q "ossapp@localhost" README.md; then
            print_success "✓ README.md 连接命令已更新"
        else
            print_error "✗ README.md 连接命令未更新"
            ((errors++))
        fi

        if grep -q "ossapp123" README.md; then
            print_success "✓ README.md 密码信息已更新"
        else
            print_error "✗ README.md 密码信息未更新"
            ((errors++))
        fi
    else
        print_error "✗ README.md 文件不存在"
        ((errors++))
    fi

    # 检查PROJECT_SUMMARY.md
    if [ -f "PROJECT_SUMMARY.md" ]; then
        print_success "✓ PROJECT_SUMMARY.md 文件存在"
    else
        print_warning "✗ PROJECT_SUMMARY.md 文件不存在"
    fi

    # 检查故障排除文档
    if [ -f "SSH_TROUBLESHOOTING.md" ]; then
        print_success "✓ SSH_TROUBLESHOOTING.md 故障排除文档存在"
    else
        print_warning "✗ SSH_TROUBLESHOOTING.md 故障排除文档不存在"
    fi

    return $errors
}

# 验证脚本文件
validate_scripts() {
    print_info "验证脚本文件..."

    local errors=0

    # 检查build.sh
    if [ -f "build.sh" ]; then
        print_success "✓ build.sh 构建脚本存在"

        if grep -q "ossapp@localhost" build.sh; then
            print_success "✓ build.sh 连接命令已更新"
        else
            print_error "✗ build.sh 连接命令未更新"
            ((errors++))
        fi
    else
        print_error "✗ build.sh 构建脚本不存在"
        ((errors++))
    fi

    # 检查troubleshoot.sh
    if [ -f "troubleshoot.sh" ]; then
        print_success "✓ troubleshoot.sh 诊断脚本存在"
    else
        print_warning "✗ troubleshoot.sh 诊断脚本不存在"
    fi

    # 检查quick_fix.sh
    if [ -f "quick_fix.sh" ]; then
        print_success "✓ quick_fix.sh 快速修复脚本存在"
    else
        print_warning "✗ quick_fix.sh 快速修复脚本不存在"
    fi

    # 检查validate.sh
    if [ -f "validate.sh" ]; then
        print_success "✓ validate.sh 验证脚本存在"
    else
        print_warning "✗ validate.sh 验证脚本不存在"
    fi

    return $errors
}

# 验证Docker Compose配置
validate_compose() {
    print_info "验证 Docker Compose 配置..."

    if [ -f "docker-compose.yml" ]; then
        if grep -q "2022:2022" docker-compose.yml; then
            print_success "✓ docker-compose.yml 端口映射配置正确"
        else
            print_warning "✗ docker-compose.yml 端口映射配置可能有问题"
        fi
    else
        print_warning "✗ docker-compose.yml 文件不存在"
    fi
}

# 验证.dockerignore
validate_dockerignore() {
    print_info "验证 .dockerignore 配置..."

    if [ -f ".dockerignore" ]; then
        print_success "✓ .dockerignore 文件存在"

        if grep -q ".git" .dockerignore; then
            print_success "✓ .dockerignore 包含 .git 忽略规则"
        else
            print_warning "✗ .dockerignore 缺少 .git 忽略规则"
        fi
    else
        print_warning "✗ .dockerignore 文件不存在"
    fi
}

# 显示配置摘要
show_config_summary() {
    print_info "配置摘要:"
    echo
    echo "=========================================="
    echo "         SSH Docker 容器配置"
    echo "=========================================="
    echo "基础镜像:        ubuntu:25.10"
    echo "SSH 端口:        2022"
    echo "默认用户:        ossapp"
    echo "用户密码:        ossapp"
    echo "root 登录:       已禁用"
    echo "访问控制:        只允许 ossapp 用户"
    echo "sudo 权限:       ossapp 用户已添加"
    echo "=========================================="
    echo
    echo "连接命令:"
    echo "  ssh ossapp@localhost -p 2022"
    echo
    echo "构建命令:"
    echo "  docker build -t ubuntu-ssh:25.10 ."
    echo
    echo "运行命令:"
    echo "  docker run -d -p 2022:2022 --name ubuntu-ssh-container ubuntu-ssh:25.10"
    echo
    echo "快速操作:"
    echo "  bash build.sh build    # 构建并运行"
    echo "  bash build.sh test     # 测试连接"
    echo "  bash build.sh diagnose # 诊断问题"
    echo "  bash build.sh fix      # 快速修复"
    echo
}

# 执行完整验证
run_full_validation() {
    echo "=========================================="
    echo "    SSH Docker 容器配置验证"
    echo "=========================================="
    echo

    local total_errors=0

    if ! validate_dockerfile; then
        ((total_errors++))
    fi
    echo

    if ! validate_documentation; then
        ((total_errors++))
    fi
    echo

    if ! validate_scripts; then
        ((total_errors++))
    fi
    echo

    validate_compose
    echo

    validate_dockerignore
    echo

    show_config_summary

    echo "=========================================="
    echo "           验证结果"
    echo "=========================================="

    if [ $total_errors -eq 0 ]; then
        print_success "所有验证通过！配置正确无误。"
        return 0
    else
        print_warning "发现 $total_errors 个问题，建议修复后使用。"
        return 1
    fi
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [验证类型]"
    echo
    echo "验证类型:"
    echo "  dockerfile   验证 Dockerfile 配置"
    echo "  docs         验证文档文件"
    echo "  scripts      验证脚本文件"
    echo "  compose      验证 Docker Compose 配置"
    echo "  dockerignore 验证 .dockerignore 配置"
    echo "  summary      显示配置摘要"
    echo "  all          全部验证 (默认)"
    echo "  help         显示此帮助信息"
}

# 主函数
main() {
    case "${1:-all}" in
        "dockerfile")
            validate_dockerfile
            ;;
        "docs")
            validate_documentation
            ;;
        "scripts")
            validate_scripts
            ;;
        "compose")
            validate_compose
            ;;
        "dockerignore")
            validate_dockerignore
            ;;
        "summary")
            show_config_summary
            ;;
        "all")
            run_full_validation
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "未知验证类型: $1"
            echo "使用 '$0 help' 查看可用验证类型"
            exit 1
            ;;
    esac
}

main "$@"
