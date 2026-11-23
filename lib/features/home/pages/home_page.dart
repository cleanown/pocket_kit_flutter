import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_kit_flutter/core/config/app_config.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () => context.push('/login'),
                child: const Text('登录'),
              ),
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
