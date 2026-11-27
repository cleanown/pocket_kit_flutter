import 'package:pocket_kit_flutter/core/auth/user_info_model.dart';
import 'package:pocket_kit_flutter/core/network/api_client.dart';
import 'package:pocket_kit_flutter/core/network/api_result_model.dart';
import 'package:pocket_kit_flutter/features/login/data/email_auth_result_model.dart';

/// 后端区分的邮箱验证码用途。
enum EmailCodePurpose {
  /// 使用已有账号登录。
  login,

  /// 创建普通账号。
  registration,

  /// 为已有账号重置密码。
  passwordReset,
}

/// 封装 Java 提供的邮箱登录、注册和密码重置接口。
final class EmailAuthApi {
  /// 使用应用统一的网络客户端，支持注入 [client]。
  EmailAuthApi({ApiClient? client}) : _client = client ?? ApiClient.shared;

  /// Java 用户端邮箱认证路由前缀。
  static const _basePath = '/api/app/auth/email';

  /// 负责发起请求和解析统一响应。
  final ApiClient _client;

  /// 向 [email] 请求当前 [purpose] 对应的一次性验证码。
  Future<ApiResultModel<void>> sendCode(
    String email,
    EmailCodePurpose purpose,
  ) {
    /// 验证码用途对应的发码路径。
    final path = switch (purpose) {
      EmailCodePurpose.login => '/code',
      EmailCodePurpose.registration => '/register/code',
      EmailCodePurpose.passwordReset => '/password/reset/code',
    };
    return _postEmpty(path, {'email': email});
  }

  /// 使用账号的 [email] 和 [password] 登录。
  Future<ApiResultModel<EmailAuthResultModel>> loginWithPassword(
    String email,
    String password,
  ) {
    return _login('/login/password', email, {'password': password});
  }

  /// 使用 [email] 收到的六位 [code] 登录。
  Future<ApiResultModel<EmailAuthResultModel>> loginWithCode(
    String email,
    String code,
  ) {
    return _login('/login', email, {'code': code});
  }

  /// 校验 [email] 的 [code] 及两次密码 [password]、[confirmPassword]，返回资料和令牌。
  Future<ApiResultModel<EmailAuthResultModel>> register(
    String email,
    String code,
    String password,
    String confirmPassword,
  ) => _client.request(
    '$_basePath/register',
    method: 'POST',
    data: {
      'email': email,
      'code': code,
      'password': password,
      'confirmPassword': confirmPassword,
    },
    decode: _decodeRegistration,
  );

  /// 验证 [email] 收到的 [code]，以 [password] 更新密码并校验 [confirmPassword]。
  Future<ApiResultModel<void>> resetPassword(
    String email,
    String code,
    String password,
    String confirmPassword,
  ) => _postEmpty('/password/reset', {
    'email': email,
    'code': code,
    'password': password,
    'confirmPassword': confirmPassword,
  });

  /// 向 [path] 提交 [email] 和 [credentials]，并返回用户资料及访问令牌。
  Future<ApiResultModel<EmailAuthResultModel>> _login(
    String path,
    String email,
    Map<String, String> credentials,
  ) {
    return _client.request(
      _basePath + path,
      method: 'POST',
      data: {'email': email, ...credentials},
      // data 为登录接口返回的业务数据。
      decode: (data) {
        /// 从登录响应中解析出的用户标识和访问令牌。
        final result = _decodeCredentials(data);
        return (
          userInfo: UserInfoModel(id: result.userId.toString(), email: email),
          token: result.token,
        );
      },
    );
  }

  /// 从注册响应 [data] 提取用户资料，校验令牌和资料属于同一账号。
  static EmailAuthResultModel _decodeRegistration(Object? data) {
    // profile 为注册资料，id 和 email 为服务端确认的用户标识和邮箱，token 为凭据对象。
    if (data
        case {
          'user':
              final Map<String, Object?> profile &&
              {'id': final int id, 'email': final String email},
          'token': final Object token,
        }
        when email.isNotEmpty) {
      /// 与新账号资料一起返回的访问凭据。
      final credentials = _decodeCredentials(token);
      if (credentials.userId == id) {
        return (
          userInfo: UserInfoModel(
            id: id.toString(),
            email: email,
            username: profile['nickname'] as String? ?? '',
            avatar: profile['avatarUrl'] as String? ?? '',
            phone: profile['phone'] as String?,
          ),
          token: credentials.token,
        );
      }
    }
    throw const FormatException('注册登录信息格式有误');
  }

  /// 从认证响应 [data] 读取正整数用户标识与非空访问令牌。
  static ({int userId, String token}) _decodeCredentials(Object? data) {
    // userId 为令牌绑定的用户标识，token 为访问令牌文本。
    if (data
        case {'userId': final int userId, 'accessToken': final String token}
        when userId > 0 && token.isNotEmpty) {
      return (userId: userId, token: token);
    }
    throw const FormatException('登录信息格式有误');
  }

  /// 向 [path] 提交 [body]，解析无额外业务数据的成功响应。
  Future<ApiResultModel<void>> _postEmpty(
    String path,
    Map<String, String> body,
  ) {
    return _client.request<void>(
      _basePath + path,
      method: 'POST',
      data: body,
      // 该接口的成功状态由统一响应码判断。
      decode: (_) {},
    );
  }
}
