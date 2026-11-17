import 'package:flutter/material.dart';
import 'package:pocket_kit_flutter/app/router.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: "百宝箱",
      routerConfig: appRouter,
    );
  }
}
