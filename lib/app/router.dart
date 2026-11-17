import 'package:go_router/go_router.dart';
import 'package:pocket_kit_flutter/features/common/web_entry.dart';
import 'package:pocket_kit_flutter/features/common/webview.dart';
import 'package:pocket_kit_flutter/features/home/pages/home_page.dart';
import 'package:pocket_kit_flutter/features/login/pages/login_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _) => const HomePage()),
    GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
    GoRoute(
      path: '/webview',
      builder: (_, state) =>
          WebviewPage(url: state.uri.queryParameters['url']!),
    ),
    GoRoute(path: '/web_entry', builder: (_, _) => const WebEntry()),
  ],
);
