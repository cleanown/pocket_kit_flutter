import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WebEntry extends StatefulWidget {
  const WebEntry({super.key});

  @override
  State<WebEntry> createState() => _WebEntryState();
}

class _WebEntryState extends State<WebEntry> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _openWebview() {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    context.push(
      Uri(
        path: '/webview',
        queryParameters: {'url': _urlController.text.trim()},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('输入网址')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _urlController,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'URL 地址',
                        hintText: 'https://example.com',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return '请输入网址';

                        final url = Uri.tryParse(text);
                        if (url == null ||
                            !url.hasAuthority ||
                            url.host.isEmpty ||
                            (url.scheme != 'http' && url.scheme != 'https') ||
                            RegExp(r'\s').hasMatch(text)) {
                          return '请输入有效的 http:// 或 https:// 地址';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _openWebview(),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _openWebview,
                      child: const Text('跳转'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
