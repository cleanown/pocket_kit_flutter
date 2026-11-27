import 'package:dio/dio.dart';
import 'package:pocket_kit_flutter/core/network/api_client.dart';
import 'package:pocket_kit_flutter/core/network/api_result_model.dart';

/// 封装 PocketKit 后端的服务状态接口。
final class ServerStatusApi {
  /// 创建服务状态接口，默认使用应用共享客户端。
  ServerStatusApi({ApiClient? client}) : _client = client ?? ApiClient.shared;

  /// 用于发起状态请求的网络客户端。
  final ApiClient _client;

  /// 读取后端根路径返回的服务状态，[cancelToken] 可用于取消请求。
  Future<ApiResultModel<String>> getServerStatus({CancelToken? cancelToken}) {
    return _client.getText('/', cancelToken: cancelToken);
  }
}
