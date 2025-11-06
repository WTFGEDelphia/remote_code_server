#!/bin/bash

# 快速启动脚本 - Docker 开发环境
# 用法: ./quick-start.sh [ubuntu|multistage]

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

# 显示帮助信息
show_help() {
    echo "Docker 开发环境快速启动脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  ubuntu            启动 Ubuntu 优化版本"
    echo "  multistage        启动 Ubuntu 多阶段构建版本"
    echo "  stop              停止所有容器"
    echo "  clean             清理所有容器和镜像"
    echo "  clean-volumes     清理所有挂载目录和数据"
    echo "  status            显示容器状态"
    echo "  verify            验证所有运行中的服务"
    echo "  dirs              显示挂载目录状态"
    echo "  help              显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 ubuntu         # 启动 Ubuntu 版本"
    echo "  $0 multistage     # 启动 Ubuntu 多阶段版本"
    echo "  $0 stop           # 停止所有容器"
}

# 检查 Docker 和 Docker Compose
check_dependencies() {
    print_info "检查依赖..."

    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi

    print_success "依赖检查通过"
}

# 创建挂载目录
create_mount_directories() {
    print_info "创建挂载目录..."

    # 检查当前目录是否包含 docker-compose.yml
    if [ ! -f "./docker-compose.yml" ]; then
        print_error "未找到 docker-compose.yml 文件"
        print_error "请确保在包含 docker-compose.yml 的目录下运行此脚本"
        print_error "当前目录: $(pwd)"
        exit 1
    fi

    print_info "当前目录: $(pwd)"
    print_info "找到 docker-compose.yml"

    # 创建议程化字典用于存储要创建的目录和对应的服务
    declare -A directories
    directories["ubuntu-wk-data"]="ubuntu"
    directories["multistage-wk-data"]="multistage"

    # 手动创建所有需要的目录
    for dir in "${!directories[@]}"; do
        if [ ! -d "./$dir" ]; then
            print_info "创建目录: ./$dir"
            if mkdir -p "./$dir"; then
                # 设置合适的权限
                chmod -R 777 "./$dir"
                print_success "目录创建成功: ./$dir"
            else
                print_error "目录创建失败: ./$dir"
                print_error "请检查权限或磁盘空间"
                exit 1
            fi
        else
            print_info "目录已存在: ./$dir"
        fi
    done

    # 验证目录创建结果
    local failed_dirs=()
    for dir in "${!directories[@]}"; do
        if [ ! -d "./$dir" ]; then
            failed_dirs+=("$dir")
            print_error "目录验证失败: ./$dir"
        fi
    done

    if [ ${#failed_dirs[@]} -gt 0 ]; then
        print_error "以下目录创建失败: ${failed_dirs[*]}"
        exit 1
    fi

    print_success "所有挂载目录准备完成"
}

# 构建镜像
build_image() {
    local type=$1
    print_info "准备构建 $type 版本镜像..."

    # 首先创建挂载目录
    create_mount_directories

    # 再次验证目录是否成功创建
    local mount_dir=""
    case $type in
        "ubuntu")
            mount_dir="./ubuntu-wk-data"
            ;;
        "multistage")
            mount_dir="./multistage-wk-data"
            ;;
    esac

    if [ ! -d "$mount_dir" ]; then
        print_error "挂载目录 $mount_dir 创建失败，无法继续构建"
        exit 1
    fi

    print_info "挂载目录验证通过: $mount_dir"

    print_info "开始构建 $type 版本镜像..."
    case $type in
        "ubuntu")
            # 删除所有构建缓存（包括其他镜像）
            docker builder prune -a -f
            # --pull：拉取基础镜像的最新版本
            # --force-rm：删除中间容器
            # --no-cache：完全跳过缓存，强制重新下载基础镜像并重建所有层
            docker-compose build --no-cache dev-ubuntu
            ;;
        "multistage")
            docker builder prune -a -f
            docker-compose build --no-cache dev-multistage
            ;;
        *)
            print_error "未知的镜像类型: $type"
            exit 1
            ;;
    esac

    print_success "$type 版本镜像构建完成"
}

# 启动服务
# 验证服务状态
verify_service() {
    local type=$1
    local port=$2
    local container_name=""

    # 确定容器名称
    case $type in
        "ubuntu")
            container_name="ossapp-dev-ubuntu"
            ;;
        "multistage")
            container_name="ossapp-dev-multistage"
            ;;
    esac

    print_info "验证 $type 服务状态..."

    # 检查容器是否运行
    if ! docker ps | grep -q "$container_name"; then
        print_error "容器 $container_name 未运行"
        return 1
    fi

    # 检查SSH服务
    if docker exec "$container_name" pgrep sshd >/dev/null 2>&1; then
        print_success "SSH 服务运行正常"
    else
        print_warning "SSH 服务未运行，尝试启动..."
        docker exec "$container_name" /usr/bin/sshd 2>/dev/null || true
        sleep 2
        if docker exec "$container_name" pgrep sshd >/dev/null 2>&1; then
            print_success "SSH 服务已启动"
        else
            print_error "SSH 服务启动失败"
            return 1
        fi
    fi

    # 检查关键二进制文件
    if docker exec "$container_name" test -f /usr/sbin/sshd; then
        print_success "SSH 二进制文件存在"
    else
        print_error "SSH 二进制文件缺失"
        return 1
    fi

    # 检查用户配置
    if docker exec "$container_name" id ossapp >/dev/null 2>&1; then
        print_success "用户 ossapp 配置正确"
    else
        print_warning "用户 ossapp 未找到"
    fi

    print_success "$type 服务验证完成"
}

# 验证所有服务
verify_all_services() {
    print_info "验证所有运行中的服务..."
    echo

    # 检查所有容器
    local running_containers=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "dev-")

    if [ -z "$running_containers" ]; then
        print_warning "没有找到运行中的开发容器"
        echo "请先启动一个服务: $0 [ubuntu|alpine|alpine-multistage|multistage]"
        return 1
    fi

    echo "运行中的容器:"
    echo "$running_containers"
    echo

    # 验证每个容器
    while IFS= read -r line; do
        if [[ $line == dev-* ]]; then
            local container_name=$(echo "$line" | awk '{print $1}')
            local container_type=""

            case $container_name in
                "dev-ubuntu")
                    container_type="ubuntu"
                    ;;
                "dev-multistage")
                    container_type="multistage"
                    ;;
            esac

            if [ -n "$container_type" ]; then
                echo "=== 验证 $container_type 容器 ==="
                verify_service "$container_type" "$(get_port_for_type "$container_type")"
                echo
            fi
        fi
    done <<< "$running_containers"
}

# 获取端口号
get_port_for_type() {
    local type=$1
    case $type in
        "ubuntu")
            echo "2022"
            ;;
        "multistage")
            echo "2023"
            ;;
    esac
}

start_service() {
    local type=$1
    local port=$2

    print_info "准备启动 $type 版本服务..."
    # 首先创建挂载目录
    create_mount_directories
    # 验证目录是否成功创建
    local mount_dir=""
    case $type in
        "ubuntu")
            mount_dir="./ubuntu-wk-data"
            port="2022"
            ;;
        "alpine")
            mount_dir="./ubuntu-wk-data"
            port="2023"
            ;;
        "alpine-multistage")
            mount_dir="./ubuntu-wk-data"
            port="2025"
            ;;
        "multistage")
            mount_dir="./multistage-wk-data"
            port="2024"
            ;;
    esac

    if [ ! -d "$mount_dir" ]; then
        print_error "挂载目录 $mount_dir 创建失败，无法启动服务"
        exit 1
    fi

    print_info "挂载目录验证通过: $mount_dir"
    print_info "使用端口: $port"

    print_info "开始启动 $type 版本服务..."
    case $type in
        "ubuntu")
            docker-compose up -d dev-ubuntu
            port="2022"
            ;;
        "multistage")
            docker-compose up -d dev-multistage
            port="2023"
            ;;
    esac

    sleep 3

    # 验证服务状态
    verify_service "$type" "$port"

    print_success "$type 版本服务已启动"
    print_info "SSH 连接信息:"
    echo "  主机: localhost"
    echo "  端口: $port"
    echo "  用户: ossapp"
    echo "  密码: ossapp (首次连接建议修改)"
    echo ""
    print_info "VS Code Remote 连接:"
    echo "  地址: ssh://ossapp@localhost:$port"
    echo ""
}

# 停止服务
stop_services() {
    print_info "停止所有服务..."
    docker-compose down
    print_success "所有服务已停止"
}

# 清理环境
clean_environment() {
    print_warning "这将删除所有容器、镜像和数据卷，是否继续? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        print_info "清理环境..."
        docker-compose down -v --rmi all
        print_success "环境清理完成"
    else
        print_info "取消清理操作"
    fi
}

# 显示状态
show_status() {
    print_info "容器状态:"
    docker-compose ps
    echo ""
    print_info "镜像信息:"
    docker images | grep "dev-" || echo "未找到相关镜像"
}

# 显示目录状态
show_directory_status() {
    print_info "挂载目录状态:"
    echo

    # 检查ubuntu开发目录
    if [ -d "./ubuntu-wk-data" ]; then
        local ubuntu_size=$(du -sh ./ubuntu-wk-data 2>/dev/null | cut -f1)
        print_success "ubuntu-wk-data 目录存在 (大小: $ubuntu_size)"
        echo "  权限: $(ls -ld ./ubuntu-wk-data | awk '{print $1, $3, $4}')"
        echo "  路径: $(pwd)/ubuntu-wk-data"
    else
        print_warning "ubuntu-wk-data 目录不存在"
        echo "  建议运行: ./quick-start.sh ubuntu"
    fi
    echo

    # 检查多阶段开发目录
    if [ -d "./multistage-wk-data" ]; then
        local multistage_size=$(du -sh ./multistage-wk-data 2>/dev/null | cut -f1)
        print_success "multistage-wk-data 目录存在 (大小: $multistage_size)"
        echo "  权限: $(ls -ld ./multistage-wk-data | awk '{print $1, $3, $4}')"
        echo "  路径: $(pwd)/multistage-wk-data"
    else
        print_warning "multistage-wk-data 目录不存在"
        echo "  建议运行: ./quick-start.sh multistage"
    fi
    echo

    print_info "Docker Volume 状态:"
    docker volume ls | grep -E "(ubuntu-dev-data|multistage-dev-data)" || echo "  未找到相关数据卷"
}

# 清理卷和目录
clean_volumes() {
    print_warning "这将删除所有挂载目录和容器数据！"
    read -p "确认删除所有数据？[y/N]: " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "停止所有容器..."
        docker-compose down

        print_info "删除Docker卷..."
        docker volume rm ubuntu-dev-data multistage-dev-data 2>/dev/null || true

        print_info "清理挂载目录..."
        rm -rf ./ubuntu-wk-data ./multistage-wk-data 2>/dev/null || true

        print_success "卷和目录清理完成"
    else
        print_info "取消清理操作"
    fi
}

# 主函数
main() {
    case "${1:-help}" in
        "ubuntu")
            check_dependencies
            build_image "ubuntu"
            start_service "ubuntu"
            ;;
        "multistage")
            check_dependencies
            build_image "multistage"
            start_service "multistage"
            ;;
        "stop")
            check_dependencies
            stop_services
            ;;
        "clean")
            check_dependencies
            clean_environment
            ;;
        "status")
            check_dependencies
            show_status
            ;;
        "verify")
            check_dependencies
            verify_all_services
            ;;
        "dirs")
            show_directory_status
            ;;
        "clean-volumes")
            check_dependencies
            clean_volumes
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "未知选项: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 捕获 Ctrl+C
trap 'print_info "操作被用户取消"; exit 130' INT

# 执行主函数
main "$@"
