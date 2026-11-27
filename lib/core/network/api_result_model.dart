import 'package:pocket_kit_flutter/core/network/api_exception.dart';

/// 接口结果，[T] 为成功时返回的业务数据类型。
sealed class ApiResultModel<T> {
  /// 供成功和失败结果创建共同的基础类型。
  const ApiResultModel();
}

/// 表示请求及响应校验均已通过。
final class ApiSuccessModel<T> extends ApiResultModel<T> {
  /// 保存成功时解析出的 [data]。
  const ApiSuccessModel(this.data);

  /// 服务端返回的业务数据，接口也可以返回空数据。
  final T data;
}

/// 表示请求、业务校验或数据解析失败。
final class ApiFailureModel<T> extends ApiResultModel<T> {
  /// 保存网络层统一处理后的 [error]。
  const ApiFailureModel(this.error);

  /// 供调用方按需读取的错误类型、状态码和提示。
  final ApiException error;
}
