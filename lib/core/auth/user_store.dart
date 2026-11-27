import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocket_kit_flutter/core/auth/user_info_model.dart';
import 'package:pocket_kit_flutter/core/shared/app_logger.dart';

/// 维护全局用户资料，并将用户资料和访问令牌分别持久化。
final class UserStore {
  /// 创建应用共用的用户存储。
  UserStore._();

  /// 应用各页面及网络层共用的用户存储。
  static final shared = UserStore._();

  /// 用户资料的本地存储键。
  static const _userInfoKey = 'userInfo';

  /// 访问令牌的本地存储键。
  static const _tokenKey = 'token';

  /// 旧版用户缓存的存储键，仅用于迁移和清理。
  static const _legacyStorageKey = 'pocket_kit_auth_session';

  /// 使用设备的安全存储服务保存资料和令牌。
  final _storage = const FlutterSecureStorage();

  /// 向界面发布当前用户的资料。
  final _userInfo = ValueNotifier(const UserInfoModel());

  /// 当前加载的访问令牌，退出后为空。
  String? _token;

  /// 串行执行持久化操作，确保登录和退出不会交叉写入。
  Future<void>? _pendingWrite;

  /// 供页面监听的用户信息。
  ValueListenable<UserInfoModel> get changes => _userInfo;

  /// 当前用户信息。
  UserInfoModel get current => _userInfo.value;

  /// 通过用户标识判断是否已登录。
  bool get isLogin => current.id.isNotEmpty;

  /// 供请求层使用的访问令牌。
  String? get token => _token;

  /// 应用启动时读取用户资料和令牌，并兼容旧版缓存。
  Future<void> init() => _write(() async {
    try {
      /// 安全存储中保存的用户资料 JSON。
      final cached = await _storage.read(key: _userInfoKey);

      /// 与用户资料独立保存的访问令牌。
      final token = await _storage.read(key: _tokenKey);
      if (cached != null && token != null && token.isNotEmpty) {
        _setUser(UserInfoModel.fromStorage(jsonDecode(cached)), token);
        return;
      }

      _setUser(const UserInfoModel(), null);
      await _migrateLegacyUser();
    } catch (_) {
      AppLogger.info('读取用户信息缓存失败');
    }
  });

  /// 保存登录或注册返回的 [userInfo] 和访问 [token]。
  Future<void> update(UserInfoModel userInfo, String token) =>
      _write(() => _save(userInfo, token));

  /// 退出登录并清除本地用户资料和令牌。
  Future<void> reset() => _write(_clear);

  /// 请求被服务端拒绝时，清除发出该请求的当前用户 [userInfo]。
  Future<void> invalidate(UserInfoModel userInfo) => _write(() async {
    if (!identical(current, userInfo)) return;
    _setUser(const UserInfoModel(), null);
    try {
      await _clear();
    } catch (_) {
      AppLogger.info('清除失效用户信息缓存失败');
    }
  });

  /// 将 [operation] 排入存储队列，单次失败交给该操作的调用方处理。
  Future<void> _write(Future<void> Function() operation) {
    /// 本次存储操作的执行结果。
    final result = (_pendingWrite ?? Future<void>.value()).then(
      (_) => operation(),
    );

    /// 吸收本次错误，使后续存储操作仍可执行。
    final queued = result.then<void>((_) {}, onError: (Object _) {});
    _pendingWrite = queued;
    return result.whenComplete(() {
      // 仅在本次操作仍是队尾时释放已完成的队列。
      if (identical(_pendingWrite, queued)) _pendingWrite = null;
    });
  }

  /// 把仍有效的旧版用户缓存转换为独立的资料和令牌。
  Future<void> _migrateLegacyUser() async {
    /// 旧版缓存的 JSON 字符串。
    final cached = await _storage.read(key: _legacyStorageKey);
    if (cached == null) return;

    // userId、email 和 accessToken 来自旧版登录，expiresAt 为 Unix 毫秒时间戳。
    if (jsonDecode(cached)
        case {
          'userId': final int userId,
          'email': final String email,
          'accessToken': final String accessToken,
          'expiresAt': final int expiresAt,
        }
        when userId > 0 &&
            email.isNotEmpty &&
            accessToken.isNotEmpty &&
            expiresAt > DateTime.now().millisecondsSinceEpoch) {
      await _save(
        UserInfoModel(id: userId.toString(), email: email),
        accessToken,
      );
    }
    await _storage.delete(key: _legacyStorageKey);
  }

  /// 先准备 [userInfo]，再写入与之对应的 [token] 完成本次登录。
  Future<void> _save(UserInfoModel userInfo, String token) async {
    // 先移除旧令牌，写入中断时启动流程不会使用不完整的登录数据。
    await _storage.delete(key: _tokenKey);
    try {
      await _storage.write(
        key: _userInfoKey,
        value: jsonEncode(userInfo.toStorage()),
      );
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {
      _setUser(const UserInfoModel(), null);
      rethrow;
    }
    _setUser(userInfo, token);
  }

  /// 清理各版本的持久化数据并发布退出状态。
  Future<void> _clear() async {
    await _storage.delete(key: _legacyStorageKey);
    await _storage.delete(key: _tokenKey);
    _setUser(const UserInfoModel(), null);
    await _storage.delete(key: _userInfoKey);
  }

  /// 更新内存中的 [token]，再发布对应的 [userInfo]。
  void _setUser(UserInfoModel userInfo, String? token) {
    _token = token;
    _userInfo.value = userInfo;
  }
}
