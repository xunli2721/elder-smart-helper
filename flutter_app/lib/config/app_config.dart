/// 服务器配置
///
/// 【使用真机调试时】请将 serverHost 改为你电脑的局域网 IP，例如 '192.168.1.100'
/// 【使用 Android 模拟器】保持 '10.0.2.2'（模拟器访问宿主机的特殊地址）
/// 【使用 iOS 模拟器 / Web】可保持 'localhost'
///
/// 生产环境构建时请通过 --dart-define 注入配置：
///   flutter build apk --dart-define=API_SCHEME=https --dart-define=SERVER_HOST=your.domain.com
class AppConfig {
  static const String serverHost = String.fromEnvironment(
    'SERVER_HOST',
    defaultValue: '192.168.15.251',
  );

  static const int serverPort = int.fromEnvironment(
    'SERVER_PORT',
    defaultValue: 3001,
  );

  static const String _scheme = String.fromEnvironment(
    'API_SCHEME',
    defaultValue: 'http',
  );

  /// API 基础地址。生产环境必须使用 https。
  static String get apiBaseUrl => '$_scheme://$serverHost:$serverPort/api';

  /// WebSocket 服务器地址。生产环境必须使用 wss。
  static String get socketUrl => '$_scheme://$serverHost:$serverPort';
}
