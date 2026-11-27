import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_kit_flutter/core/shared/app_logger.dart';

/// 网页浏览页面，在页面中央显示加载动画和进度。
class WebviewPage extends StatefulWidget {
  /// 创建网页浏览页面，[url] 为需要打开的网页地址。
  const WebviewPage({super.key, required this.url});

  /// 需要打开的网页地址。
  final String url;

  /// 创建网页浏览页面的状态。
  @override
  State<WebviewPage> createState() => _WebviewPageState();
}

/// 管理网页控制器、加载进度及页面展示。
class _WebviewPageState extends State<WebviewPage> {
  /// 当前网页的加载进度，达到 100 时隐藏加载提示。
  int loadingProgress = 0;

  /// 关闭当前 Flutter 网页浏览页面，返回打开它的上一页。
  void _goBack() {
    context.pop();
  }

  /// 将加载进度更新为 [progress]，页面销毁后不再刷新界面。
  void _updateProgress(int progress) {
    if (!mounted || loadingProgress == progress) return;
    setState(() {
      loadingProgress = progress;
    });
  }

  /// 构建网页组件，转发 JavaScript 控制台日志并监听加载进度及错误。
  Widget _buildWebView() {
    return InAppWebView(
      // controller 为创建完成的网页控制器，用于加载目标地址。
      onWebViewCreated: (controller) async {
        /// 解析传入地址，保留路径、已有查询参数及页面片段。
        final uri = Uri.parse(widget.url);

        /// 统一追加或覆盖 wvt，保留其他参数的多值形式，自动处理 ? 和 &。
        final targetUri = uri.replace(
          queryParameters: {
            ...uri.queryParametersAll,
            'wvt': ['1118'],
          },
        );
        await controller.loadUrl(
          urlRequest: URLRequest(url: WebUri(targetUri.toString())),
        );
      },
      // controller 为网页控制器，consoleMessage 包含 JavaScript 日志级别和内容。
      onConsoleMessage: (controller, consoleMessage) {
        AppLogger.info('H5打印', consoleMessage.message);
      },
      // controller 为网页控制器，url 为开始加载的地址，重新加载时重置进度。
      onLoadStart: (controller, url) => _updateProgress(0),
      // controller 为网页控制器，progress 为当前加载百分比。
      onProgressChanged: (controller, progress) => _updateProgress(progress),
      // controller 为网页控制器，url 为加载完成的地址，完成后隐藏提示。
      onLoadStop: (controller, url) => _updateProgress(100),
      // controller 为网页控制器，request 为失败请求，error 为加载错误。
      onReceivedError: (controller, request, error) {
        // 仅主页面加载失败时隐藏提示，避免子资源失败中断进度显示。
        if (request.isForMainFrame == true) {
          _updateProgress(100);
        }
      },
      // controller 为网页控制器，request 为失败请求，errorResponse 为错误响应。
      onReceivedHttpError: (controller, request, errorResponse) {
        // 主页面返回 HTTP 错误时结束加载提示。
        if (request.isForMainFrame == true) {
          _updateProgress(100);
        }
      },
    );
  }

  /// 构建无背景的居中加载提示，进度文字带阴影，允许触摸事件传递至网页。
  Widget _buildLoadingIndicator() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                '加载中 $loadingProgress%',
                style: const TextStyle(
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black87,
                      offset: Offset(0, 1),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建网页浏览页面，[context] 为当前页面的构建上下文。
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 悬浮按钮关闭当前 Flutter 页面，返回上一页。
      floatingActionButton: FloatingActionButton(
        onPressed: _goBack,
        tooltip: '返回上一页',
        child: const Icon(Icons.arrow_back),
      ),
      body: Stack(
        children: [
          _buildWebView(),
          if (loadingProgress < 100) _buildLoadingIndicator(),
        ],
      ),
    );
  }
}
