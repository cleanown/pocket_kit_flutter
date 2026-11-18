import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_kit_flutter/app/router.dart';
import 'package:pocket_kit_flutter/features/common/web_entry.dart';
import 'package:pocket_kit_flutter/features/common/webview.dart';
import 'package:pocket_kit_flutter/features/home/pages/home_page.dart';

/// 替代原生 WebView，使用真实页面和路由验证悬浮按钮的返回行为。
class TestWebViewPlatform extends InAppWebViewPlatform {
  /// 创建尚未初始化网页控制器的测试视图，[params] 为网页配置。
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) => TestWebViewWidget(params);
}

/// 保留网页加载中的状态，确保返回操作不依赖网页控制器或历史。
class TestWebViewWidget extends PlatformInAppWebViewWidget {
  /// 使用网页配置 [params] 创建测试视图。
  TestWebViewWidget(super.params) : super.implementation();

  /// 构建原生视图的占位区域，[context] 为组件上下文。
  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  /// 测试视图不创建控制器，[controller] 为平台接口要求的参数。
  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      throw UnsupportedError('测试视图不创建网页控制器');

  /// 测试视图没有需要释放的原生资源。
  @override
  void dispose() {}
}

/// 验证从不同 Flutter 页面打开网页后都能点击悬浮按钮返回。
void main() {
  setUp(() {
    InAppWebViewPlatform.instance = TestWebViewPlatform();
    appRouter.go('/');
  });

  testWidgets('网页尚未加载时，悬浮按钮从网页返回首页', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(ElevatedButton, '打开http://192.168.31.52:1102'),
    );
    // 使用固定时长推进路由动画，避免持续加载动画导致等待超时。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(WebviewPage), findsOneWidget);
    expect(find.text('加载中 0%'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(WebviewPage), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('通过网址输入页打开网页，悬浮按钮返回输入页并保留网址', (tester) async {
    /// 用于验证返回输入页后仍保留的原始网址。
    const url = 'https://example.com';
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开网页'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), url);
    await tester.tap(find.text('跳转'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(WebviewPage), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(WebviewPage), findsNothing);
    expect(find.byType(WebEntry), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      url,
    );
    expect(tester.takeException(), isNull);
  });
}
