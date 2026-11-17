import 'package:go_router/go_router.dart';
import 'package:pocket_kit_flutter/features/home/pages/home_page.dart';
import 'package:pocket_kit_flutter/features/login/pages/login_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_,_) => HomePage()),
    GoRoute(path: '/login', builder: (_,_) => LoginPage()),
  ]
);