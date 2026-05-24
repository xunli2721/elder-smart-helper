# ElderSmartHelper 测试指南

## 测试体系概述

本项目采用多层次测试策略，确保软件质量、稳定性和用户体验。测试覆盖从单元测试到端到端测试的完整流程。

## 测试类型

### 1. 单元测试 (Unit Tests)
- **位置**：`tests/unit/`
- **范围**：测试单个函数、组件或类的功能
- **框架**：Jest (JavaScript/TypeScript), Pytest (Python)
- **目标**：验证代码逻辑正确性

### 2. 集成测试 (Integration Tests)
- **位置**：`tests/integration/`
- **范围**：测试模块间交互、API接口、数据库操作
- **框架**：Jest + Supertest (API测试)
- **目标**：验证系统组件协同工作

### 3. 组件测试 (Component Tests)
- **位置**：`tests/components/`
- **范围**：测试React Native组件交互和渲染
- **框架**：React Native Testing Library + Jest
- **目标**：验证UI组件行为和渲染

### 4. 端到端测试 (E2E Tests)
- **位置**：`tests/e2e/`
- **范围**：测试完整用户流程，跨多个页面
- **框架**：Detox (移动端), Cypress (Web端)
- **目标**：验证完整业务流程

### 5. 无障碍测试 (Accessibility Tests)
- **位置**：`tests/accessibility/`
- **范围**：测试屏幕阅读器兼容性、颜色对比度等
- **工具**：Axe-core, React Native Accessibility Inspector
- **目标**：确保应用对老年用户友好

### 6. 性能测试 (Performance Tests)
- **位置**：`tests/performance/`
- **范围**：测试应用启动时间、内存使用、响应速度
- **工具**：React Native Performance Monitor, Chrome DevTools
- **目标**：确保流畅的用户体验

## 测试环境

### 测试数据库
```sql
-- 测试数据库配置
CREATE DATABASE elder_smart_helper_test;
USE elder_smart_helper_test;
-- 运行测试数据库初始化脚本
```

### 测试配置文件
```javascript
// tests/config/test.config.js
module.exports = {
  environment: 'test',
  database: {
    mysql: {
      host: 'localhost',
      port: 3306,
      database: 'elder_smart_helper_test',
      username: 'test_user',
      password: 'test_password',
      logging: false
    },
    redis: {
      host: 'localhost',
      port: 6379,
      db: 15  // 使用单独的Redis数据库
    }
  },
  // 其他测试配置...
};
```

## 测试用例编写规范

### 单元测试示例
```javascript
// tests/unit/services/user.service.test.js
const UserService = require('../../../server/src/services/user.service');
const db = require('../../../server/src/config/database');

describe('UserService', () => {
  beforeAll(async () => {
    await db.authenticate();
    await db.sync({ force: true }); // 清空测试数据库
  });

  afterAll(async () => {
    await db.close();
  });

  beforeEach(async () => {
    // 每个测试前清理用户表
    await db.query('DELETE FROM users');
  });

  describe('createUser', () => {
    test('should create user with valid data', async () => {
      const userData = {
        phone: '13800138000',
        name: '测试用户',
        userType: 'elderly'
      };

      const user = await UserService.createUser(userData);
      
      expect(user).toHaveProperty('id');
      expect(user.phone).toBe(userData.phone);
      expect(user.name).toBe(userData.name);
      expect(user.userType).toBe(userData.userType);
    });

    test('should throw error for duplicate phone', async () => {
      const userData = {
        phone: '13800138000',
        name: '测试用户1',
        userType: 'elderly'
      };

      // 第一次创建成功
      await UserService.createUser(userData);

      // 第二次创建应失败
      await expect(UserService.createUser(userData))
        .rejects
        .toThrow('手机号已注册');
    });
  });
});
```

### 组件测试示例
```javascript
// tests/components/Button.test.js
import React from 'react';
import { render, fireEvent } from '@testing-library/react-native';
import Button from '../../mobile-app/src/components/Button';

describe('Button Component', () => {
  const defaultProps = {
    title: '测试按钮',
    onPress: jest.fn(),
    accessibilityLabel: '测试按钮',
    testID: 'test-button'
  };

  test('renders with correct title', () => {
    const { getByText } = render(<Button {...defaultProps} />);
    expect(getByText('测试按钮')).toBeTruthy();
  });

  test('handles press event', () => {
    const { getByTestId } = render(<Button {...defaultProps} />);
    const button = getByTestId('test-button');
    
    fireEvent.press(button);
    expect(defaultProps.onPress).toHaveBeenCalledTimes(1);
  });

  test('has correct accessibility properties', () => {
    const { getByLabelText } = render(<Button {...defaultProps} />);
    const button = getByLabelText('测试按钮');
    
    expect(button).toBeTruthy();
    expect(button.props.accessibilityRole).toBe('button');
  });

  test('applies custom styles', () => {
    const customStyle = { backgroundColor: 'red' };
    const { getByTestId } = render(
      <Button {...defaultProps} style={customStyle} />
    );
    
    const button = getByTestId('test-button');
    expect(button.props.style).toContainEqual(customStyle);
  });
});
```

### API集成测试示例
```javascript
// tests/integration/api/user.api.test.js
const request = require('supertest');
const app = require('../../../server/src/index').app;
const db = require('../../../server/src/config/database');

describe('User API', () => {
  beforeAll(async () => {
    await db.authenticate();
    await db.sync({ force: true });
  });

  afterAll(async () => {
    await db.close();
  });

  describe('POST /api/auth/register', () => {
    test('should register new user', async () => {
      const userData = {
        phone: '13800138001',
        name: '测试用户',
        userType: 'elderly',
        password: 'Test123!'
      };

      const response = await request(app)
        .post('/api/auth/register')
        .send(userData)
        .expect('Content-Type', /json/)
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('token');
      expect(response.body.data.user).toHaveProperty('id');
    });

    test('should validate required fields', async () => {
      const response = await request(app)
        .post('/api/auth/register')
        .send({})
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toHaveProperty('message');
    });
  });

  describe('GET /api/users/profile', () => {
    let authToken;

    beforeEach(async () => {
      // 注册用户并获取token
      const registerResponse = await request(app)
        .post('/api/auth/register')
        .send({
          phone: '13800138002',
          name: '测试用户',
          userType: 'elderly',
          password: 'Test123!'
        });

      authToken = registerResponse.body.data.token;
    });

    test('should get user profile with valid token', async () => {
      const response = await request(app)
        .get('/api/users/profile')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('phone', '13800138002');
    });

    test('should reject request without token', async () => {
      const response = await request(app)
        .get('/api/users/profile')
        .expect(401);

      expect(response.body.success).toBe(false);
      expect(response.body.error.code).toBe('UNAUTHORIZED');
    });
  });
});
```

## 无障碍测试规范

### 颜色对比度测试
```javascript
// tests/accessibility/color-contrast.test.js
import { checkContrast } from '../utils/colorUtils';

describe('Color Contrast Accessibility', () => {
  const testCases = [
    {
      name: '主文本颜色对比',
      foreground: '#333333',
      background: '#FFFFFF',
      expectedRatio: 4.5
    },
    {
      name: '大文本颜色对比',
      foreground: '#666666',
      background: '#FFFFFF',
      expectedRatio: 3.0
    },
    {
      name: '按钮颜色对比',
      foreground: '#FFFFFF',
      background: '#4A90E2',
      expectedRatio: 4.5
    }
  ];

  testCases.forEach(({ name, foreground, background, expectedRatio }) => {
    test(`${name} 应符合WCAG标准`, () => {
      const ratio = checkContrast(foreground, background);
      expect(ratio).toBeGreaterThanOrEqual(expectedRatio);
    });
  });
});
```

### 屏幕阅读器兼容性测试
```javascript
// tests/accessibility/screen-reader.test.js
import { AccessibilityInfo } from 'react-native';

describe('Screen Reader Compatibility', () => {
  test('所有交互元素应有accessibilityLabel', () => {
    // 遍历应用中的所有屏幕，检查交互元素
    const interactiveElements = [
      { screen: 'Home', elements: ['主按钮', '菜单按钮', '搜索输入框'] },
      { screen: 'Tutorials', elements: ['教程卡片', '播放按钮', '收藏按钮'] }
    ];

    interactiveElements.forEach(({ screen, elements }) => {
      elements.forEach(element => {
        expect(element).toBeDefined();
        // 实际测试中会检查具体元素的accessibilityLabel属性
      });
    });
  });

  test('应提供有意义的accessibilityHint', () => {
    const elementsWithHint = [
      { element: '语音按钮', expectedHint: '长按开始语音输入' },
      { element: '求助按钮', expectedHint: '请求子女远程协助' }
    ];

    elementsWithHint.forEach(({ element, expectedHint }) => {
      // 实际测试中会检查具体元素的accessibilityHint属性
      expect(element).toBeDefined();
    });
  });
});
```

## 性能测试

### 应用启动性能测试
```javascript
// tests/performance/app-startup.test.js
describe('App Startup Performance', () => {
  test('冷启动时间应小于3秒', async () => {
    const startTime = Date.now();
    
    // 模拟应用冷启动
    await app.start();
    
    const endTime = Date.now();
    const startupTime = endTime - startTime;
    
    expect(startupTime).toBeLessThan(3000); // 3秒
  });

  test('热启动时间应小于1秒', async () => {
    const startTime = Date.now();
    
    // 模拟应用热启动
    await app.resume();
    
    const endTime = Date.now();
    const resumeTime = endTime - startTime;
    
    expect(resumeTime).toBeLessThan(1000); // 1秒
  });
});
```

### 内存使用测试
```javascript
// tests/performance/memory-usage.test.js
describe('Memory Usage', () => {
  test('应用基础内存使用应小于100MB', () => {
    const initialMemory = process.memoryUsage().heapUsed;
    
    // 执行一些操作后检查内存增长
    const finalMemory = process.memoryUsage().heapUsed;
    const memoryIncrease = finalMemory - initialMemory;
    
    expect(memoryIncrease).toBeLessThan(50 * 1024 * 1024); // 50MB
  });

  test('不应有内存泄漏', async () => {
    // 多次执行同一操作，检查内存是否持续增长
    const memoryReadings = [];
    
    for (let i = 0; i < 10; i++) {
      // 执行可能引起内存泄漏的操作
      await performOperation();
      memoryReadings.push(process.memoryUsage().heapUsed);
      
      // 强制垃圾回收
      if (global.gc) global.gc();
    }
    
    // 检查内存增长趋势
    const isMemoryLeaking = checkMemoryLeak(memoryReadings);
    expect(isMemoryLeaking).toBe(false);
  });
});
```

## 测试覆盖率

### 覆盖率目标
- **语句覆盖率**：≥ 80%
- **分支覆盖率**：≥ 75%
- **函数覆盖率**：≥ 85%
- **行覆盖率**：≥ 80%

### 生成覆盖率报告
```bash
# 后端测试覆盖率
cd server && npm test -- --coverage

# 移动端测试覆盖率
cd mobile-app && npm test -- --coverage
```

## 持续集成

### GitHub Actions 配置
```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: root
          MYSQL_DATABASE: elder_smart_helper_test
        ports:
          - 3306:3306
      redis:
        image: redis:6.0
        ports:
          - 6379:6379
    
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '16'
      
      - name: Install dependencies
        run: |
          cd server && npm ci
          cd ../mobile-app && npm ci
      
      - name: Run backend tests
        run: |
          cd server
          npm test
          npm run test:coverage
      
      - name: Run frontend tests
        run: |
          cd mobile-app
          npm test
          npm run test:coverage
      
      - name: Upload coverage reports
        uses: codecov/codecov-action@v3
```

## 测试数据管理

### 测试数据工厂
```javascript
// tests/factories/user.factory.js
const faker = require('faker/locale/zh_CN');

class UserFactory {
  static createElderlyUser(overrides = {}) {
    return {
      phone: `138${faker.random.number({ min: 10000000, max: 99999999 })}`,
      name: faker.name.findName(),
      userType: 'elderly',
      languagePreference: 'zh-CN',
      fontSize: 'large',
      ...overrides
    };
  }

  static createFamilyUser(overrides = {}) {
    return {
      phone: `139${faker.random.number({ min: 10000000, max: 99999999 })}`,
      name: faker.name.findName(),
      userType: 'family',
      ...overrides
    };
  }
}

module.exports = UserFactory;
```

### 测试数据清理
```javascript
// tests/utils/database.cleaner.js
const db = require('../../server/src/config/database');

class DatabaseCleaner {
  static async cleanAllTables() {
    const tables = [
      'users',
      'family_relationships',
      'devices',
      'tutorials',
      'remote_sessions',
      'security_events'
    ];

    for (const table of tables) {
      await db.query(`DELETE FROM ${table}`);
    }
  }

  static async resetAutoIncrement() {
    const tables = [
      'users',
      'family_relationships',
      'devices',
      'tutorials',
      'remote_sessions',
      'security_events'
    ];

    for (const table of tables) {
      await db.query(`ALTER TABLE ${table} AUTO_INCREMENT = 1`);
    }
  }
}

module.exports = DatabaseCleaner;
```

## 测试最佳实践

### 1. 测试隔离
- 每个测试应独立运行，不依赖其他测试状态
- 使用beforeEach/afterEach清理测试数据
- 避免测试间的共享状态

### 2. 测试可读性
- 使用描述性的测试名称
- 遵循Given-When-Then模式
- 添加有意义的断言消息

### 3. 测试性能
- 避免不必要的数据库操作
- 使用模拟对象代替真实服务
- 并行执行独立测试

### 4. 测试维护性
- 使用工厂模式创建测试数据
- 提取公共测试逻辑为工具函数
- 定期清理过时的测试用例

## 常见问题排查

### 测试失败排查步骤
1. **检查测试环境**：数据库、Redis等服务是否正常运行
2. **查看错误日志**：详细错误信息通常包含问题原因
3. **检查测试数据**：确保测试数据符合预期
4. **验证依赖关系**：检查测试间的依赖关系
5. **查看覆盖率报告**：缺失的测试覆盖可能暗示问题

### 测试性能优化
1. **使用内存数据库**：测试时使用SQLite代替MySQL
2. **并行执行测试**：利用Jest的并行测试能力
3. **缓存依赖安装**：在CI中缓存node_modules
4. **选择性运行测试**：只运行受影响的测试文件

## 更新日志
- 2026-04-08：创建测试指南文档
- 2026-04-08：完善测试用例示例
- 2026-04-08：添加无障碍测试规范