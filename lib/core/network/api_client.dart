import 'package:dio/dio.dart';
import 'package:pocket_kit_flutter/core/config/app_config.dart';
import 'package:pocket_kit_flutter/core/logging/app_logger.dart';
import 'package:pocket_kit_flutter/core/network/api_exception.dart';

/// 统一发送 PocketKit 后端请求并转成业务数据或接口异常。
final class ApiClient {
  /// 创建请求客户端，可通过 [dio] 注入自定义传输配置。
  ApiClient({Dio? dio}) : _dio = dio ?? _createDio();

  /// 应用中各业务 API 默认共用的客户端。
  static final ApiClient shared = ApiClient();

  /// 负责实际 HTTP 通信的 Dio 实例。
  final Dio _dio;

  /// 发送 JSON 业务请求，并用 [decode] 将响应的 `data` 转成所需类型。
  /// [path] 为接口路径，[method] 为请求方法，[data] 为请求体。
  /// [queryParameters] 为查询参数，[headers] 为额外请求头，[cancelToken] 可取消请求。
  Future<T> request<T>(
    String path, {
    String method = 'GET',
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    required T Function(Object? data) decode,
  }) async {
    /// 后端返回的 HTTP 响应及已解析的响应体。
    final response = await _send(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(method: method, headers: headers),
      cancelToken: cancelToken,
    );

    /// 业务响应体应包含整数类型的业务状态码。
    final body = response.data;
    // envelope 为业务响应，code 为独立于 HTTP 状态码的业务状态码。
    if (body
        case final Map<String, Object?> envelope && {'code': final int code}) {
      if (code != 200) {
        throw ApiException(
          type: ApiErrorType.business,
          message: _readMessage(body) ?? '请求处理失败',
          statusCode: response.statusCode,
          code: code,
        );
      }

      try {
        return decode(envelope['data']);
      } on FormatException catch (_, stackTrace) {
        // 保留业务模型解析失败的位置，并提供统一的错误类型。
        Error.throwWithStackTrace(_invalidResponse(response), stackTrace);
      } on TypeError catch (_, stackTrace) {
        // 字段类型不匹配时同样向业务层返回响应格式异常。
        Error.throwWithStackTrace(_invalidResponse(response), stackTrace);
      }
    }

    throw _invalidResponse(response);
  }

  /// 获取 [path] 返回的纯文本，[cancelToken] 可用于取消请求。
  Future<String> getText(String path, {CancelToken? cancelToken}) async {
    /// 纯文本接口的 HTTP 响应。
    final response = await _send(path, cancelToken: cancelToken);

    /// 后端返回的原始文本内容。
    final body = response.data;
    if (body is String) return body;

    throw _invalidResponse(response);
  }

  /// 创建应用默认使用的 Dio 实例，并统一记录请求结果。
  static Dio _createDio() {
    return Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      )
      ..interceptors.add(
        InterceptorsWrapper(
          // response 为成功返回的 HTTP 响应，handler 将响应传给下一处理环节。
          onResponse: (response, handler) {
            _logRequest(response.requestOptions, response.statusCode);
            handler.next(response);
          },
          // error 为 Dio 请求异常，handler 将异常传给调用方处理。
          onError: (error, handler) {
            _logRequest(
              error.requestOptions,
              error.response?.statusCode ?? error.type.name,
            );
            handler.next(error);
          },
        ),
      );
  }

  /// 记录 [request] 的方法、路径及 [result]，省略查询参数和请求内容。
  static void _logRequest(RequestOptions request, Object? result) {
    AppLogger.info('HTTP ${request.method} ${request.uri.path}', result);
  }

  /// 发送 [path] 对应的请求，并将 Dio 异常转换为业务可识别的异常。
  /// [data] 为请求体，[queryParameters] 为查询参数，[options] 为单次请求配置。
  /// [cancelToken] 可取消该请求。
  Future<Response<Object?>> _send(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.request<Object?>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (error, stackTrace) {
      // 保留 Dio 首次抛出请求异常时的堆栈。
      Error.throwWithStackTrace(_fromDioException(error), stackTrace);
    }
  }

  /// 将 [error] 的 Dio 异常类型、HTTP 状态及后端错误体转成统一错误。
  static ApiException _fromDioException(DioException error) {
    /// 服务端错误响应体，连接失败时可能为空。
    final body = error.response?.data;

    /// 根据异常类型确定分类和可展示的提示。
    final (type, message) = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => (ApiErrorType.timeout, '请求超时，请重试'),
      DioExceptionType.connectionError => (ApiErrorType.connection, '无法连接服务器'),
      DioExceptionType.badCertificate => (ApiErrorType.connection, '服务器证书校验失败'),
      DioExceptionType.cancel => (ApiErrorType.cancelled, '请求已取消'),
      DioExceptionType.badResponse => (
        ApiErrorType.http,
        _readMessage(body) ?? '服务器请求失败',
      ),
      DioExceptionType.unknown when error.error is FormatException => (
        ApiErrorType.invalidResponse,
        '服务器响应格式有误',
      ),
      DioExceptionType.unknown => (ApiErrorType.unknown, '请求失败，请重试'),
    };

    return ApiException(
      type: type,
      message: message,
      statusCode: error.response?.statusCode,
      code: switch (body) {
        {'code': final int code} => code,
        _ => null,
      },
    );
  }

  /// 读取 [body] 中后端返回的非空错误提示。
  static String? _readMessage(Object? body) => switch (body) {
    {'message': final String message} when message.trim().isNotEmpty => message,
    _ => null,
  };

  /// 根据 [response] 创建响应格式异常，并保留 HTTP 状态码。
  static ApiException _invalidResponse(Response<Object?> response) {
    return ApiException(
      type: ApiErrorType.invalidResponse,
      message: '服务器响应格式有误',
      statusCode: response.statusCode,
    );
  }
}
