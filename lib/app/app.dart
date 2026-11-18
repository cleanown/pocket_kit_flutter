import 'package:flutter/material.dart';
import 'package:pocket_kit_flutter/app/router.dart';

/// 应用入口，统一配置路由和黑白灰简约主题。
class App extends StatelessWidget {
  /// 创建百宝箱应用。
  const App({super.key});

  /// 构建应用，[context] 为当前组件的上下文。
  @override
  Widget build(BuildContext context) {
    /// 使用单色方案生成中性色阶，统一按钮、输入框和加载动画的颜色。
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF262626),
      dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
      primary: const Color(0xFF262626),
      onPrimary: Colors.white,
      surface: Colors.white,
    );

    return MaterialApp.router(
      title: "百宝箱",
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarThemeData(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF262626),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 0,
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 2,
        ),
      ),
      routerConfig: appRouter,
    );
  }
}
