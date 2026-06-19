/**
 * 简单结构化日志工具
 * 生产环境可替换为 winston / pino 等
 */

const LOG_LEVEL = process.env.LOG_LEVEL || 'info';
const LEVELS = { error: 0, warn: 1, info: 2, debug: 3 };
const currentLevel = LEVELS[LOG_LEVEL] ?? 2;

function formatMessage(level, msg, meta) {
  const timestamp = new Date().toISOString();
  const base = `[${timestamp}] [${level.toUpperCase()}] ${msg}`;
  if (meta && Object.keys(meta).length > 0) {
    return `${base} ${JSON.stringify(meta)}`;
  }
  return base;
}

const logger = {
  error(msg, meta = {}) {
    if (currentLevel >= 0) console.error(formatMessage('error', msg, meta));
  },
  warn(msg, meta = {}) {
    if (currentLevel >= 1) console.warn(formatMessage('warn', msg, meta));
  },
  info(msg, meta = {}) {
    if (currentLevel >= 2) console.log(formatMessage('info', msg, meta));
  },
  debug(msg, meta = {}) {
    if (currentLevel >= 3) console.log(formatMessage('debug', msg, meta));
  },
};

module.exports = logger;
