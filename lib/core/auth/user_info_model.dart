/// 保存应用使用的用户资料，字段与 uni-app 的用户信息对应。
final class UserInfoModel {
  /// 使用服务端资料创建用户信息，未提供的字段使用默认值。
  const UserInfoModel({
    this.id = '',
    this.email = '',
    this.username = '',
    this.avatar = '',
    this.account = '',
    this.phone,
  });

  /// 从本地缓存的 [data] 中还原已登录用户的资料。
  factory UserInfoModel.fromStorage(Object? data) {
    // id 和 email 为登录时写入的用户标识和邮箱。
    if (data
        case final Map<String, Object?> fields &&
            {'id': final String id, 'email': final String email}
        when (int.tryParse(id) ?? 0) > 0 && email.isNotEmpty) {
      return UserInfoModel(
        id: id,
        email: email,
        username: fields['username'] as String? ?? '',
        avatar: fields['avatar'] as String? ?? '',
        account: fields['account'] as String? ?? '',
        phone: fields['phone'] as String?,
      );
    }
    throw const FormatException('用户信息缓存格式有误');
  }

  /// 字符串形式的用户标识，空值表示未登录。
  final String id;

  /// 当前用户的邮箱地址。
  final String email;

  /// 用户昵称。
  final String username;

  /// 用户头像地址。
  final String avatar;

  /// 用户账号名称。
  final String account;

  /// 用户绑定的手机号，保留服务端返回的文本格式。
  final String? phone;

  /// 将用户资料转换为可持久化的字段。
  Map<String, Object?> toStorage() => {
    'id': id,
    'email': email,
    'username': username,
    'avatar': avatar,
    'account': account,
    'phone': phone,
  };
}
