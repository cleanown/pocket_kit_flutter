import 'package:pocket_kit_flutter/core/auth/user_info_model.dart';

/// 邮箱认证结果，userInfo 为用户资料，token 为访问令牌。
typedef EmailAuthResultModel = ({UserInfoModel userInfo, String token});
