/**
 * 统一 API 响应格式
 */
function success(res, data = null, message = 'success', statusCode = 200) {
  return res.status(statusCode).json({
    success: true,
    data,
    message
  });
}

function fail(res, message = '操作失败', statusCode = 400) {
  return res.status(statusCode).json({
    success: false,
    message
  });
}

function created(res, data = null, message = '创建成功') {
  return success(res, data, message, 201);
}

function notFound(res, message = '资源不存在') {
  return fail(res, message, 404);
}

function unauthorized(res, message = '未登录') {
  return fail(res, message, 401);
}

function forbidden(res, message = '没有操作权限') {
  return fail(res, message, 403);
}

module.exports = { success, fail, created, notFound, unauthorized, forbidden };
