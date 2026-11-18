import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 统一输出带时间、级别和颜色的日志，支持键名与键值及对象 JSON 转换。
abstract final class AppLogger {
  /// 标记调用时未传入键值，用于区分省略参数和显式传入 null。
  static const Object _missingValue = Object();

  /// 日志总开关，默认仅在调试模式输出，可按需手动调整。
  static bool enabled = kDebugMode;

  /// 是否输出 ANSI 颜色，不支持颜色的控制台可将此项关闭。
  static bool useColors = true;

  /// 输出灰色调试日志，[message] 为键名或单独的内容，[value] 为可选键值。
  static void debug(Object? message, [Object? value = _missingValue]) {
    _log('DEBUG', message, '\x1B[90m', value);
  }

  /// 输出蓝色普通日志，[message] 为键名或单独的内容，[value] 为可选键值。
  static void info(Object? message, [Object? value = _missingValue]) {
    _log('INFO', message, '\x1B[34m', value);
  }

  /// 输出绿色成功日志，[message] 为键名或单独的内容，[value] 为可选键值。
  static void success(Object? message, [Object? value = _missingValue]) {
    _log('SUCCESS', message, '\x1B[32m', value);
  }

  /// 输出黄色警告日志，[message] 为键名或单独的内容，[value] 为可选键值。
  static void warning(Object? message, [Object? value = _missingValue]) {
    _log('WARNING', message, '\x1B[33m', value);
  }

  /// 输出红色错误日志，[message] 为键名或单独的内容，[value] 为键值或异常。
  /// [stackTrace] 为可选堆栈，调用示例：AppLogger.error('请求失败', error, stackTrace)。
  static void error(
    Object? message, [
    Object? value = _missingValue,
    StackTrace? stackTrace,
  ]) {
    if (!enabled) return;

    /// 汇总键名、键值及堆栈，未传入的可选内容不输出。
    final parts = <String>[
      _formatEntry(message, value),
      if (stackTrace != null) '堆栈：\n$stackTrace',
    ];
    _log('ERROR', parts.join('\n'), '\x1B[31m');
  }

  /// 格式化键值日志，[message] 为键名或单独的内容，[value] 为键值。
  /// 未传入键值时保留单参数输出，多个值可组合为 List 或 Map 传入。
  static String _formatEntry(Object? message, Object? value) {
    /// 键名的文本表示，单参数时直接作为完整日志内容。
    final title = _formatMessage(message);
    if (identical(value, _missingValue)) return title;

    /// 键名已有中英文冒号时只补空格，避免重复添加分隔符。
    final separator = RegExp(r'[:：]\s*$').hasMatch(title) ? ' ' : '：';
    return '$title$separator${_formatMessage(value)}';
  }

  /// 格式化 [message]：字符串保持原样，其余内容优先转为 JSON，转换失败时回退为文本。
  static String _formatMessage(Object? message) {
    if (message is String) return message;

    try {
      return jsonEncode(message);
    } on JsonUnsupportedObjectError {
      // 包含循环引用或不支持 JSON 的对象时，继续输出对象的文本表示。
      return '$message';
    }
  }

  /// 统一输出日志，[level] 为级别，[message] 为键名或内容，[color] 为 ANSI 颜色。
  /// [value] 为可选键值，保留显式传入的 null、false、0 及空字符串。
  static void _log(
    String level,
    Object? message,
    String color, [
    Object? value = _missingValue,
  ]) {
    if (!enabled) return;

    /// 使用本地时间生成当前日志的时间标记。
    final now = DateTime.now();

    /// 格式为 HH:mm:ss.SSS，便于区分短时间内的连续日志。
    final time =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';

    /// 兼容换行格式，为多行内容的每一行分别添加时间、级别和颜色。
    final lines = _formatEntry(
      message,
      value,
    ).replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

    // line 为当前需要输出的一行日志内容。
    for (final line in lines) {
      /// 当前行完整日志，颜色在每行末尾恢复，避免影响后续控制台输出。
      final text = '[$time][$level] $line';
      debugPrint(useColors ? '$color$text\x1B[0m' : text);
    }
  }
}
