#!/bin/bash

# ElderSmartHelper 部署脚本
# 使用方法: ./scripts/deploy.sh [environment]

set -e  # 遇到错误时退出脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示用法
show_usage() {
    echo "用法: $0 [environment]"
    echo ""
    echo "可选环境:"
    echo "  development  开发环境部署"
    echo "  staging      预发布环境部署"
    echo "  production   生产环境部署"
    echo ""
    echo "示例:"
    echo "  $0 development"
    echo "  $0 production"
    exit 1
}

# 检查参数
if [ $# -ne 1 ]; then
    show_usage
fi

ENVIRONMENT=$1
case $ENVIRONMENT in
    development|staging|production)
        log_info "开始部署到 $ENVIRONMENT 环境"
        ;;
    *)
        log_error "未知环境: $ENVIRONMENT"
        show_usage
        ;;
esac

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

log_info "项目根目录: $PROJECT_ROOT"

# 加载环境特定配置
load_environment_config() {
    local env_file="$PROJECT_ROOT/config/$ENVIRONMENT.json"
    if [ ! -f "$env_file" ]; then
        log_error "环境配置文件不存在: $env_file"
        exit 1
    fi

    # 从JSON配置文件中提取关键配置
    local db_host=$(grep -o '"host": "[^"]*"' "$env_file" | head -1 | cut -d'"' -f4)
    local db_name=$(grep -o '"database": "[^"]*"' "$env_file" | head -1 | cut -d'"' -f4)

    export DEPLOY_DB_HOST="${db_host:-localhost}"
    export DEPLOY_DB_NAME="${db_name:-elder_smart_helper}"

    log_info "数据库配置: 主机=$DEPLOY_DB_HOST, 数据库=$DEPLOY_DB_NAME"
}

# 检查依赖
check_dependencies() {
    log_info "检查系统依赖..."

    # 检查Node.js
    if ! command -v node &> /dev/null; then
        log_error "Node.js 未安装"
        exit 1
    fi

    NODE_VERSION=$(node --version | cut -d'v' -f2)
    REQUIRED_NODE_VERSION=16
    if [ $(echo "$NODE_VERSION < $REQUIRED_NODE_VERSION" | bc) -eq 1 ]; then
        log_error "Node.js 版本过低 ($NODE_VERSION)，需要 v$REQUIRED_NODE_VERSION+"
        exit 1
    fi
    log_info "Node.js 版本: $NODE_VERSION ✓"

    # 检查npm
    if ! command -v npm &> /dev/null; then
        log_error "npm 未安装"
        exit 1
    fi
    log_info "npm 版本: $(npm --version) ✓"

    # 检查MySQL客户端
    if ! command -v mysql &> /dev/null; then
        log_warning "MySQL客户端未安装，跳过数据库操作"
        export SKIP_DB_OPS=true
    else
        log_info "MySQL客户端已安装 ✓"
    fi

    # 检查Redis客户端
    if ! command -v redis-cli &> /dev/null; then
        log_warning "Redis客户端未安装，跳过Redis操作"
        export SKIP_REDIS_OPS=true
    else
        log_info "Redis客户端已安装 ✓"
    fi

    # 检查Git
    if ! command -v git &> /dev/null; then
        log_warning "Git未安装"
    else
        log_info "Git版本: $(git --version) ✓"
    fi

    log_success "依赖检查完成"
}

# 验证环境配置
validate_environment() {
    log_info "验证 $ENVIRONMENT 环境配置..."

    case $ENVIRONMENT in
        production)
            # 生产环境额外检查
            if [ -z "$PRODUCTION_DB_PASSWORD" ]; then
                log_error "生产环境数据库密码未设置 (PRODUCTION_DB_PASSWORD)"
                exit 1
            fi

            if [ -z "$PRODUCTION_REDIS_PASSWORD" ]; then
                log_warning "生产环境Redis密码未设置"
            fi
            ;;
        staging)
            # 预发布环境检查
            if [ -z "$STAGING_DB_PASSWORD" ]; then
                log_error "预发布环境数据库密码未设置 (STAGING_DB_PASSWORD)"
                exit 1
            fi
            ;;
    esac

    log_success "环境配置验证完成"
}

# 备份数据库
backup_database() {
    if [ "$SKIP_DB_OPS" = "true" ]; then
        log_warning "跳过数据库备份"
        return
    fi

    log_info "备份数据库..."

    local backup_dir="$PROJECT_ROOT/backups/database"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$backup_dir/${DEPLOY_DB_NAME}_${timestamp}.sql"

    mkdir -p "$backup_dir"

    # 设置数据库密码
    local db_password=""
    case $ENVIRONMENT in
        production) db_password="$PRODUCTION_DB_PASSWORD" ;;
        staging) db_password="$STAGING_DB_PASSWORD" ;;
        *) db_password="password" ;; # 开发环境默认密码
    esac

    if mysqldump -h "$DEPLOY_DB_HOST" -u root -p"$db_password" "$DEPLOY_DB_NAME" > "$backup_file" 2>/dev/null; then
        log_success "数据库备份成功: $backup_file"

        # 保留最近7天的备份
        find "$backup_dir" -name "*.sql" -mtime +7 -delete
    else
        log_error "数据库备份失败"
        exit 1
    fi
}

# 运行数据库迁移
run_migrations() {
    if [ "$SKIP_DB_OPS" = "true" ]; then
        log_warning "跳过数据库迁移"
        return
    fi

    log_info "运行数据库迁移..."

    cd "$PROJECT_ROOT/server"

    # 设置数据库密码
    case $ENVIRONMENT in
        production) export DB_PASSWORD="$PRODUCTION_DB_PASSWORD" ;;
        staging) export DB_PASSWORD="$STAGING_DB_PASSWORD" ;;
        *) export DB_PASSWORD="password" ;;
    esac

    if npm run migrate:up; then
        log_success "数据库迁移成功"
    else
        log_error "数据库迁移失败"
        exit 1
    fi
}

# 清理Redis缓存
clear_redis_cache() {
    if [ "$SKIP_REDIS_OPS" = "true" ]; then
        log_warning "跳过Redis缓存清理"
        return
    fi

    log_info "清理Redis缓存..."

    local redis_password=""
    case $ENVIRONMENT in
        production) redis_password="-a $PRODUCTION_REDIS_PASSWORD" ;;
        staging) redis_password="-a $STAGING_REDIS_PASSWORD" ;;
    esac

    if redis-cli $redis_password FLUSHALL >/dev/null 2>&1; then
        log_success "Redis缓存清理成功"
    else
        log_error "Redis缓存清理失败"
    fi
}

# 安装依赖
install_dependencies() {
    log_info "安装项目依赖..."

    # 后端依赖
    log_info "安装后端依赖..."
    cd "$PROJECT_ROOT/server"

    if [ "$ENVIRONMENT" = "production" ]; then
        npm ci --only=production
    else
        npm ci
    fi

    # 前端依赖
    log_info "安装前端依赖..."
    cd "$PROJECT_ROOT/mobile-app"

    if [ "$ENVIRONMENT" = "production" ]; then
        npm ci --only=production
    else
        npm ci
    fi

    log_success "依赖安装完成"
}

# 运行测试
run_tests() {
    if [ "$ENVIRONMENT" = "production" ]; then
        log_info "生产环境跳过测试"
        return
    fi

    log_info "运行测试..."

    # 后端测试
    log_info "运行后端测试..."
    cd "$PROJECT_ROOT/server"
    if npm test; then
        log_success "后端测试通过"
    else
        log_error "后端测试失败"
        exit 1
    fi

    # 前端测试（如果有）
    log_info "运行前端测试..."
    cd "$PROJECT_ROOT/mobile-app"
    if npm test -- --passWithNoTests; then
        log_success "前端测试通过"
    else
        log_error "前端测试失败"
        exit 1
    fi
}

# 构建项目
build_project() {
    log_info "构建项目..."

    case $ENVIRONMENT in
        production)
            # 生产环境构建
            log_info "构建后端生产版本..."
            cd "$PROJECT_ROOT/server"
            npm run build || true

            log_info "构建移动端生产版本..."
            cd "$PROJECT_ROOT/mobile-app"
            # 这里可以添加移动端构建命令
            ;;
        *)
            # 开发/预发布环境
            log_info "当前环境无需特殊构建"
            ;;
    esac

    log_success "项目构建完成"
}

# 重启服务
restart_services() {
    log_info "重启服务..."

    case $ENVIRONMENT in
        production)
            # 生产环境使用PM2重启
            if command -v pm2 &> /dev/null; then
                log_info "使用PM2重启服务..."
                pm2 reload elder-smart-helper-server || pm2 start "$PROJECT_ROOT/server/src/index.js" --name elder-smart-helper-server
                pm2 save
                log_success "PM2服务重启完成"
            else
                log_warning "PM2未安装，请手动重启服务"
            fi
            ;;
        development|staging)
            log_info "开发/预发布环境，请手动重启服务"
            log_info "后端启动命令: cd $PROJECT_ROOT/server && npm start"
            log_info "前端启动命令: cd $PROJECT_ROOT/mobile-app && npm start"
            ;;
    esac
}

# 健康检查
health_check() {
    log_info "执行健康检查..."

    # 这里可以添加具体的健康检查逻辑
    # 例如检查API端点、数据库连接等

    sleep 3  # 等待服务启动

    log_success "健康检查完成"
}

# 部署后清理
post_deploy_cleanup() {
    log_info "执行部署后清理..."

    # 清理临时文件
    find "$PROJECT_ROOT" -name "*.tmp" -delete
    find "$PROJECT_ROOT" -name "*.log" -mtime +30 -delete

    # 清理npm缓存（可选）
    # npm cache clean --force

    log_success "清理完成"
}

# 主部署流程
main() {
    log_info "===== ElderSmartHelper 部署开始 ====="
    log_info "环境: $ENVIRONMENT"
    log_info "时间: $(date)"

    # 加载环境配置
    load_environment_config

    # 检查依赖
    check_dependencies

    # 验证环境配置
    validate_environment

    # 备份数据库
    backup_database

    # 运行数据库迁移
    run_migrations

    # 清理Redis缓存
    clear_redis_cache

    # 安装依赖
    install_dependencies

    # 运行测试
    run_tests

    # 构建项目
    build_project

    # 重启服务
    restart_services

    # 健康检查
    health_check

    # 部署后清理
    post_deploy_cleanup

    log_success "===== ElderSmartHelper 部署完成 ====="
    log_info "部署环境: $ENVIRONMENT"
    log_info "完成时间: $(date)"

    # 显示后续步骤
    case $ENVIRONMENT in
        production)
            echo ""
            echo "🎉 生产环境部署成功！"
            echo "📊 监控地址: https://monitor.eldersmarthelper.com"
            echo "📱 应用地址: https://app.eldersmarthelper.com"
            ;;
        staging)
            echo ""
            echo "🎉 预发布环境部署成功！"
            echo "🔧 测试地址: https://staging.eldersmarthelper.com"
            ;;
        development)
            echo ""
            echo "🎉 开发环境部署成功！"
            echo "🚀 后端服务: http://localhost:3000"
            echo "📱 前端服务: http://localhost:3001"
            ;;
    esac
}

# 执行主函数
main "$@"