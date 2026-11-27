import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_kit_flutter/core/auth/user_info_model.dart';
import 'package:pocket_kit_flutter/core/auth/user_store.dart';
import 'package:pocket_kit_flutter/core/config/app_config.dart';
import 'package:pocket_kit_flutter/core/shared/app_logger.dart';
import 'package:pocket_kit_flutter/core/shared/app_toast.dart';

/// 显示账号入口与应用已有的网页入口。
class HomePage extends StatefulWidget {
  /// 创建首页。
  const HomePage({super.key});

  /// 创建首页的组件状态。
  @override
  State<HomePage> createState() => HomePageState();
}

/// 管理首页账号入口及退出操作。
class HomePageState extends State<HomePage> {
  /// 用户主动退出时锁定退出按钮。
  bool signingOut = false;

  /// 退出当前账号并在存储错误时提示用户。
  Future<void> _signOut() async {
    if (signingOut) return;
    setState(() => signingOut = true);
    try {
      await UserStore.shared.reset();
    } catch (_) {
      AppLogger.info('清除用户信息失败');
      if (mounted) AppToast.show('退出失败，请重试');
    } finally {
      if (mounted) setState(() => signingOut = false);
    }
  }

  /// 展示登录入口或当前账号的邮箱及退出操作。
  Widget _buildAccountAction() {
    return ValueListenableBuilder<UserInfoModel>(
      valueListenable: UserStore.shared.changes,
      // context 提供路由，userInfo 为当前监听到的用户资料。
      builder: (context, userInfo, _) {
        if (!UserStore.shared.isLogin) {
          return ElevatedButton(
            onPressed: () => context.push('/login'),
            child: const Text('登录'),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Text(userInfo.email, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: signingOut ? null : _signOut,
                child: const Text('退出登录'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建首页，[context] 用于打开网页入口。
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAccountAction(),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.push('/web_entry'),
                child: const Text('打开网页'),
              ),
              const SizedBox(height: 16),
              // 按钮显示配置中的 H5 地址，并将同一地址传给 WebView。
              ElevatedButton(
                onPressed: () => context.push(
                  Uri(
                    path: '/webview',
                    queryParameters: {'url': AppConfig.h5BaseUrl},
                  ).toString(),
                ),
                child: const Text('打开${AppConfig.h5BaseUrl}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
