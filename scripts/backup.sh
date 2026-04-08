#!/bin/bash

# ElderSmartHelper 备份脚本
# 用于备份数据库、上传的文件和配置文件

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
    echo "用法: $0 [backup_type]"
    echo ""
    echo "备份类型:"
    echo "  full         完全备份（数据库+文件+配置）"
    echo "  database     仅备份数据库"
    echo "  files        仅备份上传文件"
    echo "  config       仅备份配置文件"
    echo ""
    echo "示例:"
    echo "  $0 full"
    echo "  $0 database"
    exit 1
}

# 检查参数
if [ $# -ne 1 ]; then
    show_usage
fi

BACKUP_TYPE=$1
case $BACKUP_TYPE in
    full|database|files|config)
        log_info "开始执行 $BACKUP_TYPE 备份"
        ;;
    *)
        log_error "未知备份类型: $BACKUP_TYPE"
        show_usage
        ;;
esac

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 备份配置
BACKUP_ROOT="$PROJECT_ROOT/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"

# 数据库配置（根据实际情况修改）
DB_HOST="localhost"
DB_PORT="3306"
DB_NAME="elder_smart_helper"
DB_USER="root"
DB_PASSWORD="password"

# 创建备份目录
create_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    log_info "备份目录: $BACKUP_DIR"
}

# 备份数据库
backup_database() {
    log_info "备份数据库..."

    local backup_file="$BACKUP_DIR/database.sql"

    if mysqldump -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        "$DB_NAME" > "$backup_file"; then

        # 压缩备份文件
        gzip "$backup_file"
        log_success "数据库备份完成: ${backup_file}.gz"

        # 记录备份信息
        echo "数据库备份: ${backup_file}.gz" >> "$BACKUP_DIR/backup_info.txt"
    else
        log_error "数据库备份失败"
        exit 1
    fi
}

# 备份上传文件
backup_files() {
    log_info "备份上传文件..."

    local uploads_dir="$PROJECT_ROOT/server/uploads"
    local backup_file="$BACKUP_DIR/uploads.tar.gz"

    if [ -d "$uploads_dir" ]; then
        tar -czf "$backup_file" -C "$PROJECT_ROOT/server" uploads
        log_success "文件备份完成: $backup_file"

        echo "文件备份: $backup_file" >> "$BACKUP_DIR/backup_info.txt"
    else
        log_warning "上传目录不存在: $uploads_dir"
    fi
}

# 备份配置文件
backup_config() {
    log_info "备份配置文件..."

    local config_backup="$BACKUP_DIR/config.tar.gz"

    # 备份所有配置文件
    tar -czf "$config_backup" \
        -C "$PROJECT_ROOT" \
        config/ \
        server/.env \
        server/package.json \
        mobile-app/.env \
        mobile-app/package.json \
        mobile-app/app.json \
        database/schema.sql

    log_success "配置文件备份完成: $config_backup"

    echo "配置备份: $config_backup" >> "$BACKUP_DIR/backup_info.txt"
}

# 备份日志文件（可选）
backup_logs() {
    log_info "备份日志文件..."

    local logs_backup="$BACKUP_DIR/logs.tar.gz"

    if [ -d "$PROJECT_ROOT/server/logs" ]; then
        # 只备份最近7天的日志
        find "$PROJECT_ROOT/server/logs" -name "*.log" -mtime -7 | \
            tar -czf "$logs_backup" -T -

        if [ -s "$logs_backup" ]; then
            log_success "日志备份完成: $logs_backup"
            echo "日志备份: $logs_backup" >> "$BACKUP_DIR/backup_info.txt"
        else
            rm -f "$logs_backup"
            log_info "无近期日志需要备份"
        fi
    else
        log_info "日志目录不存在"
    fi
}

# 验证备份
verify_backup() {
    log_info "验证备份完整性..."

    local has_errors=0

    # 检查备份文件是否存在
    for file in "$BACKUP_DIR"/*; do
        if [ -f "$file" ]; then
            # 检查文件大小
            local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
            if [ "$file_size" -eq 0 ]; then
                log_warning "空备份文件: $(basename "$file")"
                has_errors=1
            fi

            # 检查压缩文件完整性
            if [[ "$file" == *.gz ]] || [[ "$file" == *.tar.gz ]]; then
                if ! gzip -t "$file" 2>/dev/null; then
                    log_error "损坏的压缩文件: $(basename "$file")"
                    has_errors=1
                fi
            fi
        fi
    done

    if [ $has_errors -eq 0 ]; then
        log_success "备份验证通过"
    else
        log_error "备份验证失败，部分文件可能有问题"
    fi
}

# 清理旧备份
cleanup_old_backups() {
    log_info "清理旧备份..."

    # 保留最近7天的备份
    find "$BACKUP_ROOT" -maxdepth 1 -type d -name "202*" -mtime +7 | while read -r dir; do
        log_info "删除旧备份: $dir"
        rm -rf "$dir"
    done

    # 保留最多30个备份
    local backup_count=$(find "$BACKUP_ROOT" -maxdepth 1 -type d -name "202*" | wc -l)
    if [ "$backup_count" -gt 30 ]; then
        find "$BACKUP_ROOT" -maxdepth 1 -type d -name "202*" | \
            sort | head -n $((backup_count - 30)) | while read -r dir; do
            log_info "删除超额备份: $dir"
            rm -rf "$dir"
        done
    fi

    log_success "备份清理完成"
}

# 生成备份报告
generate_backup_report() {
    log_info "生成备份报告..."

    local report_file="$BACKUP_DIR/backup_report.txt"

    {
        echo "=== ElderSmartHelper 备份报告 ==="
        echo "备份时间: $(date)"
        echo "备份类型: $BACKUP_TYPE"
        echo "备份目录: $BACKUP_DIR"
        echo ""
        echo "=== 备份内容 ==="
        if [ -f "$BACKUP_DIR/backup_info.txt" ]; then
            cat "$BACKUP_DIR/backup_info.txt"
        fi
        echo ""
        echo "=== 文件列表 ==="
        find "$BACKUP_DIR" -type f -exec ls -lh {} \;
        echo ""
        echo "=== 磁盘使用 ==="
        du -sh "$BACKUP_DIR"
        echo ""
        echo "=== 系统信息 ==="
        echo "主机名: $(hostname)"
        echo "系统时间: $(date)"
        echo "备份脚本版本: 1.0.0"
    } > "$report_file"

    log_success "备份报告生成完成: $report_file"
}

# 发送备份通知（可选）
send_backup_notification() {
    log_info "发送备份通知..."

    # 这里可以添加邮件、Slack等通知逻辑
    # 例如:
    # if [ -n "$EMAIL_RECIPIENT" ]; then
    #     mail -s "ElderSmartHelper 备份完成" "$EMAIL_RECIPIENT" < "$BACKUP_DIR/backup_report.txt"
    # fi

    log_info "备份通知功能未配置"
}

# 主备份流程
main() {
    log_info "===== ElderSmartHelper 备份开始 ====="

    # 创建备份目录
    create_backup_dir

    # 根据备份类型执行相应备份
    case $BACKUP_TYPE in
        full)
            backup_database
            backup_files
            backup_config
            backup_logs
            ;;
        database)
            backup_database
            ;;
        files)
            backup_files
            ;;
        config)
            backup_config
            backup_logs
            ;;
    esac

    # 验证备份
    verify_backup

    # 生成备份报告
    generate_backup_report

    # 清理旧备份
    cleanup_old_backups

    # 发送通知
    send_backup_notification

    log_success "===== ElderSmartHelper 备份完成 ====="

    # 显示备份信息
    echo ""
    echo "📦 备份类型: $BACKUP_TYPE"
    echo "📁 备份目录: $BACKUP_DIR"
    echo "📊 备份大小: $(du -sh "$BACKUP_DIR" | cut -f1)"
    echo "📝 备份报告: $BACKUP_DIR/backup_report.txt"
    echo ""
    echo "💾 备份文件列表:"
    find "$BACKUP_DIR" -type f -name "*.*" | while read -r file; do
        echo "  - $(basename "$file") ($(du -h "$file" | cut -f1))"
    done
}

# 执行主函数
main "$@"