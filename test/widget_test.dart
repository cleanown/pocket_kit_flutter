import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_kit_flutter/features/common/web_entry.dart';
import 'package:pocket_kit_flutter/features/home/pages/home_page.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomePage()),
        GoRoute(path: '/web_entry', builder: (_, _) => const WebEntry()),
        // Inspect the URL handoff without creating a native WebView in tests.
        GoRoute(
          path: '/webview',
          builder: (_, state) => Scaffold(
            appBar: AppBar(),
            body: Text(state.uri.queryParameters['url']!),
          ),
        ),
      ],
    );
  });

  tearDown(() => router.dispose());

  Future<void> openEntry(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('打开网页'));
    await tester.pumpAndSettle();
  }

  testWidgets('Home centers its content and opens the URL entry page', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    final content = find.ancestor(
      of: find.text('打开网页'),
      matching: find.byType(Column),
    );
    expect(tester.getCenter(content), tester.getCenter(find.byType(Scaffold)));
    expect(find.text('登录'), findsOneWidget);

    await tester.tap(find.text('打开网页'));
    await tester.pumpAndSettle();
    expect(find.byType(WebEntry), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('Empty and invalid URLs stay on the entry page', (tester) async {
    await openEntry(tester);
    await tester.tap(find.text('跳转'));
    await tester.pumpAndSettle();
    expect(find.text('请输入网址'), findsOneWidget);

    for (final url in [
      'not a url',
      'javascript:alert(1)',
      'https://',
      'https://bad host.com',
    ]) {
      await tester.enterText(find.byType(TextFormField), url);
      await tester.tap(find.text('跳转'));
      await tester.pumpAndSettle();
      expect(find.text('请输入有效的 http:// 或 https:// 地址'), findsOneWidget);
      expect(find.byType(WebEntry), findsOneWidget);
    }
  });

  testWidgets('Jump preserves query parameters, encoding and fragment', (
    tester,
  ) async {
    const url = 'https://example.com/search?q=flutter%20web&next=a+b#section';
    await openEntry(tester);
    await tester.enterText(find.byType(TextFormField), '  $url  ');
    await tester.tap(find.text('跳转'));
    await tester.pumpAndSettle();

    expect(find.text(url), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(WebEntry), findsOneWidget);
    expect(find.text('  $url  '), findsOneWidget);
  });

  testWidgets('Keyboard go opens an HTTP URL', (tester) async {
    const url = 'http://localhost:8080/path';
    await openEntry(tester);
    await tester.enterText(find.byType(TextFormField), url);
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    expect(find.text(url), findsOneWidget);
  });
}
