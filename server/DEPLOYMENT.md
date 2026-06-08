# 后端部署指南

## 环境要求

- Node.js v16+
- MySQL 8.0+
- npm 或 yarn

## 部署方式

### 方式一：Docker 部署（推荐）

```bash
# 1. 克隆项目
git clone https://gitee.com/lzbaawso/elder-smart-helper.git
cd elder-smart-helper

# 2. 配置环境变量
cp .env.docker .env
# 编辑 .env 文件，修改 JWT_SECRET 等敏感配置

# 3. 启动服务
docker-compose up -d

# 4. 查看日志
docker-compose logs -f server
```

### 方式二：手动部署

```bash
# 1. 安装依赖
cd server
npm install

# 2. 配置环境变量
cp .env.example .env
# 编辑 .env 文件

# 3. 初始化数据库
mysql -u root -p < ../database/migrations/001_initial_schema.sql
mysql -u root -p elder_smart_helper < ../database/seeds/001_sample_data.sql

# 4. 启动服务
npm start
```

### 方式三：PM2 部署（生产环境推荐）

```bash
# 1. 安装 PM2
npm install -g pm2

# 2. 启动服务
cd server
pm2 start src/index.js --name elder-server

# 3. 设置开机自启
pm2 startup
pm2 save

# 4. 查看状态
pm2 status
pm2 logs elder-server
```

## 环境变量说明

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| PORT | 服务端口 | 3000 |
| NODE_ENV | 运行环境 | development |
| DB_HOST | 数据库地址 | localhost |
| DB_PORT | 数据库端口 | 3306 |
| DB_NAME | 数据库名称 | elder_smart_helper |
| DB_USER | 数据库用户 | root |
| DB_PASSWORD | 数据库密码 | - |
| JWT_SECRET | JWT 密钥 | - |
| CORS_ORIGIN | 允许的来源 | http://localhost:3000 |

## 健康检查

服务启动后访问：
```
GET http://localhost:3000/health
```

返回：
```json
{
  "status": "ok",
  "time": "2026-06-08T12:00:00.000Z"
}
```

## API 文档

启动服务后访问：
```
http://localhost:3000/api/docs
```
