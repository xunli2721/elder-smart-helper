module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/tests/**/*.test.js'],
  collectCoverageFrom: [
    'src/**/*.js',
    '!src/index.js',
    '!src/config/db.js'
  ],
  coverageDirectory: 'coverage',
  verbose: true,
  // 确保测试环境有 JWT_SECRET
  globals: {},
};