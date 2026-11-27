import 'package:flutter/material.dart';
import 'package:pocket_kit_flutter/app/app.dart';
import 'package:pocket_kit_flutter/core/auth/user_store.dart';

/// 从本地恢复用户信息后启动百宝箱。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserStore.shared.init();
  runApp(const App());
}
