# 数据库备份与恢复指南

## 备份策略

### 备份频率建议

| 环境 | 全量备份 | 增量备份 | 保留时间 |
|------|----------|----------|----------|
| 生产环境 | 每天 | 每小时 | 30 天 |
| 测试环境 | 每周 | - | 7 天 |
| 开发环境 | 手动 | - | - |

## 备份方法

### 1. 使用 mysqldump 备份

```bash
# 全量备份
mysqldump -u root -p elder_smart_helper > backup_$(date +%Y%m%d_%H%M%S).sql

# 仅备份结构
mysqldump -u root-p --no-data elder_smart_helper > schema_backup.sql

# 仅备份数据
mysqldump -u root -p --no-create-info elder_smart_helper > data_backup.sql

# 压缩备份
mysqldump -u root -p elder_smart_helper | gzip > backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

### 2. 自动备份脚本

创建 `backup.sh`：
```bash
#!/bin/bash

# 配置
DB_NAME="elder_smart_helper"
DB_USER="root"
BACKUP_DIR="/var/backups/mysql"
RETENTION_DAYS=30

# 创建备份目录
mkdir -p $BACKUP_DIR

# 执行备份
BACKUP_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).sql.gz"
mysqldump -u $DB_USER -p $DB_NAME | gzip > $BACKUP_FILE

# 删除过期备份
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $BACKUP_FILE"
```

设置定时任务：
```bash
# 每天凌晨 2 点执行备份
crontab -e
0 2 * * * /path/to/backup.sh
```

### 3. Docker 环境备份

```bash
# 备份
docker exec elder-mysql mysqldump -u root -prootpassword elder_smart_helper > backup.sql

# 压缩备份
docker exec elder-mysql mysqldump -u root -prootpassword elder_smart_helper | gzip > backup.sql.gz
```

## 恢复方法

### 1. 从 SQL 文件恢复

```bash
# 恢复完整备份
mysql -u root -p elder_smart_helper < backup.sql

# 恢复压缩备份
gunzip < backup.sql.gz | mysql -u root -p elder_smart_helper
```

### 2. 从 Docker 备份恢复

```bash
# 恢复到 Docker 容器
docker exec -i elder-mysql mysql -u root -prootpassword elder_smart_helper < backup.sql
```

### 3. 恢复单个表

```bash
# 从完整备份中提取单个表
mysql -u root -p elder_smart_helper < backup.sql --tables users
```

## 备份验证

定期验证备份是否可恢复：

```bash
# 创建测试数据库
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS elder_smart_helper_test;"

# 恢复到测试数据库
mysql -u root -p elder_smart_helper_test < backup.sql

# 验证数据
mysql -u root -p -e "SELECT COUNT(*) FROM elder_smart_helper_test.users;"

# 清理测试数据库
mysql -u root -p -e "DROP DATABASE elder_smart_helper_test;"
```

## 灾难恢复流程

1. **评估损失**：确定数据丢失的范围和时间点
2. **停止服务**：防止进一步的数据写入
3. **恢复备份**：使用最近的全量备份恢复
4. **应用增量**：如果有增量备份，按时间顺序应用
5. **验证数据**：检查关键数据是否完整
6. **重启服务**：确认无误后重启应用

## 注意事项

- 备份文件应存储在不同于数据库服务器的位置
- 定期测试恢复流程，确保备份有效
- 生产环境备份应加密存储
- 记录每次备份的时间和大小
- 监控备份任务的执行状态
