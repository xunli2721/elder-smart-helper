/**
 * 数据库种子数据脚本
 * 使用: node src/seed.js
 */
const bcrypt = require('bcryptjs');
const db = require('./config/db');

const users = [
  { phone: '13800001111', name: '张大爷', user_type: 'elderly', font_size: 'large' },
  { phone: '13800002222', name: '李大妈', user_type: 'elderly', font_size: 'xlarge' },
  { phone: '13900001111', name: '张小明', user_type: 'family', font_size: 'medium' },
  { phone: '13900002222', name: '李小红', user_type: 'family', font_size: 'medium' },
  { phone: '13700001111', name: '王管理员', user_type: 'admin', font_size: 'medium' },
];

const tutorials = [
  {
    title: '如何拨打电话',
    description: '学习使用智能手机拨打电话的基本操作',
    category: 'basic',
    difficulty_level: 'beginner',
    steps: JSON.stringify([
      { title: '进入拨号界面', description: '在手机桌面上找到绿色电话图标，轻轻点击它', image: '', order: 1 },
      { title: '输入电话号码', description: '在拨号键盘上，依次点击要拨打的电话号码数字', image: '', order: 2 },
      { title: '拨出电话', description: '确认号码正确后，点击下方绿色的拨号按钮', image: '', order: 3 },
      { title: '结束通话', description: '通话结束后，点击红色挂断按钮', image: '', order: 4 },
    ]),
  },
  {
    title: '如何使用微信发消息',
    description: '学习使用微信给家人发送文字和语音消息',
    category: 'communication',
    difficulty_level: 'beginner',
    steps: JSON.stringify([
      { title: '打开微信', description: '在手机桌面找到绿色微信图标，轻轻点击打开', image: '', order: 1 },
      { title: '找到联系人', description: '在聊天列表中，找到您想联系的人，点击进入聊天', image: '', order: 2 },
      { title: '发送文字消息', description: '点击底部的输入框，用输入法打字，完成后点击发送按钮', image: '', order: 3 },
      { title: '发送语音消息', description: '按住左下角的麦克风图标不放，对准手机说话，说完后松手即可发送', image: '', order: 4 },
    ]),
  },
  {
    title: '如何连接WiFi',
    description: '学习如何连接家庭无线网络，节省手机流量',
    category: 'basic',
    difficulty_level: 'beginner',
    steps: JSON.stringify([
      { title: '打开设置', description: '在手机桌面找到齿轮形状的设置图标，轻轻点击', image: '', order: 1 },
      { title: '找到WLAN选项', description: '在设置列表中，找到WLAN或Wi-Fi选项，点击进入', image: '', order: 2 },
      { title: '开启WiFi', description: '确认顶部的WiFi开关是打开的（蓝色或绿色表示开启）', image: '', order: 3 },
      { title: '选择网络', description: '在可用网络列表中，找到您家的WiFi名称，轻轻点击', image: '', order: 4 },
      { title: '输入密码', description: '输入WiFi密码（通常写在路由器背面），点击连接', image: '', order: 5 },
    ]),
  },
  {
    title: '如何使用手机拍照',
    description: '学习使用手机相机拍摄照片的基本方法',
    category: 'entertainment',
    difficulty_level: 'beginner',
    steps: JSON.stringify([
      { title: '打开相机', description: '在手机桌面找到相机图标，轻轻点击打开', image: '', order: 1 },
      { title: '对准拍摄对象', description: '将手机对准您想拍摄的人或物体', image: '', order: 2 },
      { title: '对焦', description: '在屏幕上轻轻点击您想让照片最清晰的位置', image: '', order: 3 },
      { title: '拍照', description: '点击屏幕下方中间的圆形快门按钮，听到咔擦声表示拍照成功', image: '', order: 4 },
      { title: '查看照片', description: '点击右下角的缩略图，可以查看刚刚拍摄的照片', image: '', order: 5 },
    ]),
  },
  {
    title: '如何使用手机支付',
    description: '学习使用微信或支付宝进行安全支付',
    category: 'payment',
    difficulty_level: 'intermediate',
    steps: JSON.stringify([
      { title: '打开支付应用', description: '找到微信或支付宝图标，轻轻点击打开', image: '', order: 1 },
      { title: '打开扫一扫', description: '点击首页的扫一扫或收付款功能', image: '', order: 2 },
      { title: '扫描付款码', description: '将手机摄像头对准商家的收款二维码', image: '', order: 3 },
      { title: '输入金额', description: '输入需要支付的金额，仔细核对是否正确', image: '', order: 4 },
      { title: '确认支付', description: '确认金额无误后，输入支付密码或使用指纹确认', image: '', order: 5 },
    ]),
  },
];

async function seed() {
  try {
    // 清空已有数据
    await db.query('SET FOREIGN_KEY_CHECKS = 0');
    await db.query('TRUNCATE TABLE remote_sessions');
    await db.query('TRUNCATE TABLE family_relationships');
    await db.query('TRUNCATE TABLE tutorials');
    await db.query('TRUNCATE TABLE users');
    await db.query('SET FOREIGN_KEY_CHECKS = 1');

    // 创建用户
    const defaultPassword = await bcrypt.hash('123456', 10);
    const userIds = [];
    for (const user of users) {
      const [result] = await db.query(
        'INSERT INTO users (phone, password, name, user_type, font_size) VALUES (?, ?, ?, ?, ?)',
        [user.phone, defaultPassword, user.name, user.user_type, user.font_size]
      );
      userIds.push(result.insertId);
    }
    console.log(`创建了 ${users.length} 个用户 (密码: 123456)`);

    // 创建家庭绑定关系
    await db.query(
      'INSERT INTO family_relationships (elderly_user_id, family_user_id, relationship, permission_level) VALUES (?, ?, ?, ?)',
      [userIds[0], userIds[2], 'child', 'assist']
    );
    await db.query(
      'INSERT INTO family_relationships (elderly_user_id, family_user_id, relationship, permission_level) VALUES (?, ?, ?, ?)',
      [userIds[1], userIds[3], 'child', 'assist']
    );
    console.log('创建了 2 组家庭绑定关系');

    // 创建教程
    for (const tutorial of tutorials) {
      await db.query(
        'INSERT INTO tutorials (title, description, category, difficulty_level, steps) VALUES (?, ?, ?, ?, ?)',
        [tutorial.title, tutorial.description, tutorial.category, tutorial.difficulty_level, tutorial.steps]
      );
    }
    console.log(`创建了 ${tutorials.length} 条教程`);

    console.log('\n种子数据初始化完成!');
    console.log('---');
    console.log('测试账号:');
    console.log('  老人用户 1: 13800001111 / 123456 (张大爷)');
    console.log('  老人用户 2: 13800002222 / 123456 (李大妈)');
    console.log('  家人用户 1: 13900001111 / 123456 (张小明)');
    console.log('  家人用户 2: 13900002222 / 123456 (李小红)');
    console.log('  管理员账号: 13700001111 / 123456 (王管理员)');

    process.exit(0);
  } catch (err) {
    console.error('种子数据初始化失败:', err.message);
    process.exit(1);
  }
}

seed();
