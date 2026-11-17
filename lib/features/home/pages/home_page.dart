import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
              ElevatedButton(
                onPressed: () => context.push(
                  Uri(
                    path: '/webview',
                    queryParameters: {'url': 'http://192.168.31.52:1102/'},
                  ).toString(),
                ),
                child: const Text('打开http://192.168.31.52:1102'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
