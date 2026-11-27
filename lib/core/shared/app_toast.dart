import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// 统一设置全局 Toast 的位置、样式和显示时长。
abstract final class AppToast {
  /// 负责在应用浮层中显示提示的 fluttertoast 实例。
  static final _toast = FToast();

  /// 为应用的 [child] 安装 Toast 浮层，[context] 由应用构建器提供。
  static Widget buildHost(BuildContext context, Widget? child) {
    return Overlay.wrap(
      child: _BuildToastHost(child: child ?? const SizedBox.shrink()),
    );
  }

  /// 显示 [message] 并持续 [duration]，新消息替换正在显示的提示。
  static void show(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (_toast.context?.mounted != true) return;

    _toast
      ..removeQueuedCustomToasts()
      ..showToast(
        gravity: ToastGravity.BOTTOM,
        toastDuration: duration,
        fadeDuration: Duration.zero,
        ignorePointer: true,
        child: Semantics(
          liveRegion: true,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xE6262626),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      );
  }
}

/// 向 fluttertoast 提供浮层内部的上下文。
class _BuildToastHost extends StatefulWidget {
  /// 挂载应用的 [child] 并管理 Toast 的生命周期。
  const _BuildToastHost({required this.child});

  /// 应用的路由内容。
  final Widget child;

  /// 创建与当前应用浮层绑定的状态。
  @override
  State<_BuildToastHost> createState() => _BuildToastHostState();
}

/// 绑定浮层上下文，并在应用卸载时清理提示。
class _BuildToastHostState extends State<_BuildToastHost> {
  /// 绑定位于应用浮层内的上下文。
  @override
  void initState() {
    super.initState();
    AppToast._toast.init(context);
  }

  /// 释放当前宿主持有的 Toast 和定时器。
  @override
  void dispose() {
    if (identical(AppToast._toast.context, context)) {
      AppToast._toast
        ..removeQueuedCustomToasts()
        ..context = null;
    }
    super.dispose();
  }

  /// 展示路由内容，[context] 位于 Toast 浮层内部。
  @override
  Widget build(BuildContext context) => widget.child;
}
