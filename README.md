# ElderSmartHelper - 中老年人智能手机使用智能助手

#### 介绍
ElderSmartHelper 是一款专为中老年人设计的智能手机使用智能助手软件，旨在帮助中老年群体跨越数字鸿沟，轻松使用智能手机。软件聚焦中老年用户习惯，提供简化的交互界面、图文教学、远程协助等核心辅助功能。

#### 项目背景
随着智能手机功能日益复杂，界面小、图标多、操作层级深等问题让中老年用户望而生畏。学习成本高、子女远程协助不便等问题制约了中老年群体享受数字化生活的便利。ElderSmartHelper 致力于为中老年人提供贴心、易用的智能手机使用助手。

#### 核心痛点
- **操作复杂**：界面繁杂，功能隐蔽，学习曲线陡峭
- **学习成本高**：缺乏适合中老年人的图文教程
- **远程协助不便**：子女难以实时协助父母解决问题
- **无障碍支持不足**：字体小、对比度低

#### 解决方案
- **极简交互**：大字体、大图标、无广告，一键直达常用功能
- **手把手教学**：图文分步演示，覆盖打电话、微信、WiFi 等基础操作
- **远程协助**：子女可通过截图标注、文字指导实时帮助父母解决问题
- **个性化适配**：支持字体大小调节，适应不同用户需求

#### 功能模块
1. **用户注册与绑定**：手机号注册，支持老人与家人账号绑定
2. **适老化界面**：大字体、大图标、高对比度，无广告干扰
3. **基础功能教学**：图文分步演示，涵盖打电话、微信、WiFi 等操作
4. **快捷功能入口**：一键打开健康码、扫码、乘车、缴费等常用功能
5. **远程协助**：截图 + 标注 + 文字聊天，子女远程指导父母操作
6. **个人设置**：字体大小、个人信息管理

#### 技术栈
- **前端**：Flutter (跨平台移动应用，Android)
- **后端**：Node.js + Express
- **数据库**：MySQL
- **实时通信**：WebSocket (Socket.io，用于远程协助)
- **认证**：JWT
- **安全**：诈骗检测、支付风险预警
- **部署**：Docker + PM2

#### 安装教程

##### 环境要求
- Flutter SDK 3.0+
- Android Studio（Android 开发）
- Node.js v16+
- MySQL 8.0+

##### 克隆项目
```bash
git clone https://gitee.com/lzbaawso/elder-smart-helper.git
cd elder-smart-helper
```

##### 后端服务启动
```bash
cd server
npm install
# 配置 .env 文件（参考 .env.example）
# 初始化数据库
mysql -u root -p < ../database/schema.sql
npm run dev
```

##### Flutter 应用启动
```bash
cd flutter_app
flutter pub get
flutter run
```

##### Docker 部署（推荐）
```bash
# 配置环境变量
cp .env.docker .env
# 编辑 .env 文件

# 启动服务
docker-compose up -d
```

#### API 文档

启动后端服务后，访问以下地址查看 API 文档：
```
http://localhost:3000/api/docs
```

#### 安全功能

本项目包含以下安全功能：
- **诈骗检测**：识别文本中的诈骗关键词和可疑链接
- **支付风险预警**：检测大额支付、高频支付、深夜支付等异常行为
- **安全事件记录**：记录所有安全相关事件，支持查询和标记已解决

#### 测试

```bash
# 运行后端测试
cd server
npm test

# 运行 Flutter 测试
cd flutter_app
flutter test
```

#### 使用说明

##### 对于中老年用户
1. **首次使用**：请子女协助完成注册和绑定
2. **界面熟悉**：主界面展示常用功能大图标，点击即可使用
3. **学习操作**：进入教程模块，按步骤学习手机基本操作
4. **遇到问题**：点击"远程协助"按钮，向家人发起求助

##### 对于子女/协助者
1. **绑定父母账号**：注册后添加父母账号，建立协助关系
2. **远程协助**：当父母求助时，查看截图并标注指导
3. **教学管理**：为父母推荐合适的学习教程

#### 项目结构
```
elder-smart-helper/
├── flutter_app/              # Flutter 移动端应用
│   ├── lib/                  # 源代码
│   ├── test/                 # 测试文件
│   ├── BUILD.md              # 构建指南
│   └── pubspec.yaml          # 依赖配置
├── server/                   # Node.js 后端服务
│   ├── src/                  # 源代码
│   │   ├── controllers/      # 控制器
│   │   ├── routes/           # 路由
│   │   ├── services/         # 服务层
│   │   ├── middleware/       # 中间件
│   │   └── config/           # 配置
│   ├── tests/                # 测试文件
│   ├── Dockerfile            # Docker 配置
│   └── DEPLOYMENT.md         # 部署指南
├── database/                 # 数据库脚本
│   ├── migrations/           # 迁移脚本
│   ├── seeds/                # 种子数据
│   ├── run_migration.js      # 迁移工具
│   └── BACKUP.md             # 备份指南
├── docker-compose.yml        # Docker Compose 配置
└── README.md
```

#### 路线图
- [x] 第一阶段：项目规划与文档完善
- [x] 第二阶段：后端 API 开发（用户认证、教程、远程协助）
- [x] 第三阶段：Flutter 前端开发（全部页面与功能联调）
- [x] 第四阶段：数据库迁移与种子数据
- [x] 第五阶段：后端测试（单元测试 + 集成测试，105 个测试用例）
- [x] 第六阶段：Flutter 测试（模型测试 + Widget 测试）
- [x] 第七阶段：Docker 部署配置
- [x] 第八阶段：API 文档（Swagger UI）
- [x] 第九阶段：安全功能（诈骗检测、支付风险预警）
- [x] 第十阶段：推送通知服务
- [x] 第十一阶段：项目文档补全（DEPLOYMENT、BUILD、BACKUP）

#### 许可证
本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

#### 联系我们
- **项目地址**：[https://gitee.com/lzbaawso/elder-smart-helper](https://gitee.com/lzbaawso/elder-smart-helper)
- **问题反馈**：请提交 [Issue](https://gitee.com/lzbaawso/elder-smart-helper/issues)

---
*让科技温暖生活，让智能连接亲情*
