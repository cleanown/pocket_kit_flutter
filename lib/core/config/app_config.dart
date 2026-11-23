/// 集中维护应用使用的固定地址等静态配置。
abstract final class AppConfig {
  /// 后端 API 基础地址，供接入后端的网络请求使用。
  static const String apiBaseUrl = 'http://192.168.31.69:1123';

  /// 首页快捷入口打开的 H5 地址。
  static const String h5BaseUrl = 'http://192.168.31.52:1102/';
}
