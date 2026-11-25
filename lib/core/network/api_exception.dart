/// 页面可识别的接口请求错误类型。
enum ApiErrorType {
  /// 网络连接失败或证书校验失败。
  connection,

  /// 建立连接、发送请求、接收或转换响应超时。
  timeout,

  /// 调用方主动取消请求。
  cancelled,

  /// 服务器返回 HTTP 错误状态。
  http,

  /// HTTP 请求成功，但响应体的业务状态码表示失败。
  business,

  /// 响应体或业务数据格式不符合接口约定。
  invalidResponse,

  /// 网络层遇到的其他错误。
  unknown,
}

/// 向业务模块和页面提供统一的网络异常。
final class ApiException implements Exception {
  /// 创建接口异常，可额外携带响应状态和业务错误码。
  const ApiException({
    required this.type,
    required this.message,
    this.statusCode,
    this.code,
  });

  /// 错误类型，用于判断是否需要提示用户。
  final ApiErrorType type;

  /// 可展示给用户的错误提示。
  final String message;

  /// 服务器响应的 HTTP 状态码，未收到响应时为空。
  final int? statusCode;

  /// 后端响应体中的业务错误码。
  final int? code;

  /// 返回易读的错误信息。
  @override
  String toString() => message;
}
