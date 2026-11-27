import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_kit_flutter/core/config/app_config.dart';
import 'package:pocket_kit_flutter/core/network/api_client.dart';
import 'package:pocket_kit_flutter/core/network/api_exception.dart';
import 'package:pocket_kit_flutter/core/network/api_result_model.dart';
import 'package:pocket_kit_flutter/features/status/data/server_status_api.dart';

/// 替换真实服务器，按 [RequestOptions] 模拟后端响应或网络错误。
final class _TestAdapter implements HttpClientAdapter {
  /// 使用指定回调处理发出的请求。
  _TestAdapter(this.respond);

  /// 接收实际发送的请求配置并返回测试响应。
  final ResponseBody Function(RequestOptions options) respond;

  /// 返回 [options] 对应的测试响应，适配器无需消费请求流和取消回调。
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);

  /// 测试适配器没有连接需要关闭。
  @override
  void close({bool force = false}) {}
}

/// 使用 [respond] 创建测试客户端，保留 Dio 的响应转换和异常处理。
ApiClient _buildClient(ResponseBody Function(RequestOptions options) respond) {
  /// 保留正式的后端地址，实际传输由测试适配器完成。
  final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl))
    ..httpClientAdapter = _TestAdapter(respond);
  addTearDown(() => dio.close(force: true));
  return ApiClient(dio: dio);
}

/// 将 [body] 和 [statusCode] 组成测试所需的 JSON HTTP 响应。
ResponseBody _jsonResponse(String body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    body,
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// 验证业务 JSON、纯文本及错误响应共用同一套请求封装。
void main() {
  test('发送配置中的请求参数并解析业务数据', () async {
    /// 用于检查实际发出的 POST 请求。
    final client = _buildClient((options) {
      expect(options.baseUrl, AppConfig.apiBaseUrl);
      expect(options.path, '/items');
      expect(options.method, 'POST');
      expect(options.queryParameters, {'page': 1});
      expect(options.headers['x-test-header'], 'test');
      expect(options.data, {'name': 'PocketKit'});
      return _jsonResponse('{"code":200,"message":"成功","data":{"id":7}}');
    });

    /// 解码回调从响应的 data 字段提取条目编号。
    final result = await client.request<int>(
      '/items',
      method: 'POST',
      queryParameters: {'page': 1},
      headers: {'x-test-header': 'test'},
      data: {'name': 'PocketKit'},
      decode: (data) => (data as Map<String, Object?>)['id'] as int,
    );

    expect(
      result,
      isA<ApiSuccessModel<int>>().having((result) => result.data, '条目编号', 7),
    );
  });

  test('业务成功响应允许 data 为空', () async {
    /// 模拟没有业务数据的成功返回。
    final client = _buildClient(
      (_) => _jsonResponse('{"code":200,"message":"成功","data":null}'),
    );

    expect(
      await client.request<Object?>('/items', decode: (data) => data),
      isA<ApiSuccessModel<Object?>>().having(
        (result) => result.data,
        '成功数据',
        isNull,
      ),
    );
  });

  test('HTTP 200 下的业务错误保留后端错误码和提示', () async {
    /// 模拟后端用 HTTP 200 携带自定义业务错误码。
    final client = _buildClient(
      (_) => _jsonResponse('{"code":1001,"message":"条目已存在"}'),
    );

    expect(
      await client.request<Object?>('/items', decode: (data) => data),
      isA<ApiFailureModel<Object?>>().having(
        (result) => result.error,
        '业务错误',
        isA<ApiException>()
            .having((error) => error.type, '错误类型', ApiErrorType.business)
            .having((error) => error.statusCode, 'HTTP 状态码', 200)
            .having((error) => error.code, '业务错误码', 1001)
            .having((error) => error.message, '错误提示', '条目已存在'),
      ),
    );
  });

  test('HTTP 错误保留响应状态和后端错误体', () async {
    /// 模拟后端返回带 JSON 错误体的 HTTP 401。
    final client = _buildClient(
      (_) => _jsonResponse('{"code":401,"message":"请先登录"}', statusCode: 401),
    );

    expect(
      await client.request<Object?>('/items', decode: (data) => data),
      isA<ApiFailureModel<Object?>>().having(
        (result) => result.error,
        'HTTP 错误',
        isA<ApiException>()
            .having((error) => error.type, '错误类型', ApiErrorType.http)
            .having((error) => error.statusCode, 'HTTP 状态码', 401)
            .having((error) => error.code, '业务错误码', 401)
            .having((error) => error.message, '错误提示', '请先登录'),
      ),
    );
  });

  test('业务数据类型不匹配时返回响应格式异常', () async {
    /// 模拟返回字符串的接口，用于验证预期整数时的转换错误。
    final client = _buildClient(
      (_) => _jsonResponse('{"code":200,"message":"成功","data":"无数据"}'),
    );

    expect(
      await client.request<int>('/items', decode: (data) => data as int),
      isA<ApiFailureModel<int>>().having(
        (result) => result.error.type,
        '错误类型',
        ApiErrorType.invalidResponse,
      ),
    );
  });

  test('主动取消和接收超时返回不同的异常类型', () async {
    /// 模拟服务器响应超时。
    final client = _buildClient((options) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    });

    /// 先取消的令牌会阻止请求到达适配器。
    final cancelToken = CancelToken()..cancel();
    expect(
      await client.getText('/', cancelToken: cancelToken),
      isA<ApiFailureModel<String>>().having(
        (result) => result.error.type,
        '错误类型',
        ApiErrorType.cancelled,
      ),
    );
    expect(
      await client.getText('/'),
      isA<ApiFailureModel<String>>().having(
        (result) => result.error.type,
        '错误类型',
        ApiErrorType.timeout,
      ),
    );
  });

  test('服务状态接口通过 GET 获取后端根路径返回的纯文本', () async {
    /// 模拟 Java 后端根路径的纯文本响应。
    final client = _buildClient((options) {
      expect(options.path, '/');
      expect(options.method, 'GET');
      return ResponseBody.fromString(
        '服务器运行中',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/plain;charset=UTF-8'],
        },
      );
    });

    expect(
      await ServerStatusApi(client: client).getServerStatus(),
      isA<ApiSuccessModel<String>>().having(
        (result) => result.data,
        '服务状态',
        '服务器运行中',
      ),
    );
  });
}
