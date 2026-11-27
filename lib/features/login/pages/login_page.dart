import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_kit_flutter/core/auth/user_store.dart';
import 'package:pocket_kit_flutter/core/network/api_result_model.dart';
import 'package:pocket_kit_flutter/core/shared/app_logger.dart';
import 'package:pocket_kit_flutter/core/shared/app_toast.dart';
import 'package:pocket_kit_flutter/features/login/data/email_auth_api.dart';
import 'package:pocket_kit_flutter/features/login/data/email_auth_result_model.dart';

/// 登录与找回、注册共用的页面流程。
enum AuthMode {
  /// 使用密码登录，不需要验证码。
  password(null, '欢迎回来', '使用邮箱登录你的百宝箱账号。', '登录'),

  /// 使用邮箱验证码登录。
  code(EmailCodePurpose.login, '欢迎回来', '使用邮箱登录你的百宝箱账号。', '登录'),

  /// 创建新的普通用户账号。
  register(EmailCodePurpose.registration, '创建账号', '验证邮箱，创建你的百宝箱账号。', '注册'),

  /// 通过邮箱验证更新已有账号的密码。
  reset(EmailCodePurpose.passwordReset, '重置密码', '验证账号邮箱后设置新密码。', '重置密码');

  /// 配置流程的 [codePurpose]、页面 [title]、[description] 与提交 [action]。
  const AuthMode(this.codePurpose, this.title, this.description, this.action);

  /// 当前流程发码时使用的服务端用途。
  final EmailCodePurpose? codePurpose;

  /// 当前表单的标题。
  final String title;

  /// 当前表单的说明。
  final String description;

  /// 提交按钮的动作名称。
  final String action;
}

/// 百宝箱账号登录、注册与重置密码页面。
class LoginPage extends StatefulWidget {
  /// 创建认证页，可注入 [api] 以使用指定网络客户端。
  const LoginPage({super.key, this.api});

  /// 认证接口，默认使用应用的共享网络配置。
  final EmailAuthApi? api;

  /// 创建并维护认证表单状态。
  @override
  State<LoginPage> createState() => LoginPageState();
}

/// 负责认证表单输入、请求及页面切换。
class LoginPageState extends State<LoginPage> {
  /// 认证页的品牌主色。
  static const accentColor = Color(0xFF4338CA);

  /// 标题及输入内容的颜色。
  static const inkColor = Color(0xFF172033);

  /// 说明及占位文字的颜色。
  static const secondaryColor = Color(0xFF526176);

  /// 卡片及控件边框颜色。
  static const lineColor = Color(0xFFE1E6EF);

  /// 当前页面使用的后端接口。
  late final authApi = widget.api ?? EmailAuthApi();

  /// 邮箱输入，在四种认证表单间共享。
  final emailController = TextEditingController();

  /// 邮件中的六位数字验证码。
  final codeController = TextEditingController();

  /// 用户输入的账号密码或新密码。
  final passwordController = TextEditingController();

  /// 注册或重置时再次输入的新密码。
  final confirmController = TextEditingController();

  /// 按验证码用途及邮箱记录最早可以重发的时间。
  final resendTimes = <(EmailCodePurpose, String), DateTime>{};

  /// 用于更新验证码剩余等待时间的定时器。
  Timer? countdownTimer;

  /// 当前展示的认证流程。
  AuthMode mode = AuthMode.password;

  /// 主密码输入是否可见。
  bool passwordVisible = false;

  /// 确认密码输入是否可见。
  bool confirmationVisible = false;

  /// 发码请求是否仍在执行。
  bool sending = false;

  /// 表单是否正在向后端提交。
  bool submitting = false;

  /// 显示给用户的错误文本。
  String errorMessage = '';

  /// 表单动作成功给用户的反馈。
  String statusMessage = '';

  /// 当前是否显示登录方式切换栏。
  bool get isLogin => mode == AuthMode.password || mode == AuthMode.code;

  /// 请求期间锁定输入与流程切换。
  bool get busy => sending || submitting;

  /// 当前邮箱和用途还需要等待的重发秒数。
  int get remainingSeconds {
    /// 当前模式的验证码用途。
    final purpose = mode.codePurpose;
    if (purpose == null) return 0;

    /// 此邮箱及验证码用途的下一次允许发送时间。
    final nextSendAt = resendTimes[(purpose, emailController.text.trim())];
    if (nextSendAt == null) return 0;

    /// 按毫秒取整，避免剩余不足一秒时提前开放按钮。
    final remaining = nextSendAt.difference(DateTime.now()).inMilliseconds;
    return remaining > 0 ? (remaining + 999) ~/ 1000 : 0;
  }

  /// 释放表单控制器及倒计时资源。
  @override
  void dispose() {
    countdownTimer?.cancel();
    emailController.dispose();
    codeController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  /// 切换到 [nextMode]，保留邮箱并清除上一个流程的凭据。
  void _changeMode(AuthMode nextMode) {
    if (busy || nextMode == mode) return;
    FocusScope.of(context).unfocus();
    codeController.clear();
    passwordController.clear();
    confirmController.clear();
    setState(() {
      mode = nextMode;
      passwordVisible = false;
      confirmationVisible = false;
      errorMessage = '';
      statusMessage = '';
    });
  }

  /// 返回入口页，支持直接打开登录路由。
  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  /// 更新表单反馈，[error] 为错误信息，[status] 为成功提示。
  void _showFeedback({String error = '', String status = ''}) {
    setState(() {
      errorMessage = error;
      statusMessage = status;
    });
  }

  /// 读取经过基础格式校验的邮箱。
  String? _readEmail() {
    /// 前后空白被忽略，邮箱本地部分保留原样。
    final address = emailController.text.trim();
    if (address.length > 320 ||
        !RegExp(r'^[^@\s]+@[^@\s]+$').hasMatch(address)) {
      _showFeedback(error: '请输入有效的邮箱地址');
      return null;
    }
    return address;
  }

  /// 更新倒计时，清理所有到期的重发记录。
  void _tickCountdown() {
    /// 用于判断重发时机的本地时间。
    final now = DateTime.now();
    setState(() {
      // 键区分邮箱及用途，nextSendAt 表示此记录允许再次发码的时间。
      resendTimes.removeWhere((_, nextSendAt) => !nextSendAt.isAfter(now));
    });
    if (resendTimes.isEmpty) {
      countdownTimer?.cancel();
      countdownTimer = null;
    }
  }

  /// 请求发送当前用途对应的六位验证码。
  Future<void> _httpSendCode() async {
    /// 本次请求在服务端对应的验证码用途。
    final purpose = mode.codePurpose;
    if (purpose == null || busy || remainingSeconds > 0) return;
    _showFeedback();

    /// 本次发送的邮箱地址。
    final address = _readEmail();
    if (address == null) return;
    setState(() => sending = true);

    try {
      /// 发码成功后才开始重发倒计时。
      final result = await authApi.sendCode(address, purpose);
      if (!mounted || result is! ApiSuccessModel<void>) return;
      resendTimes[(purpose, address)] = DateTime.now().add(
        const Duration(seconds: 60),
      );
      // 定时器参数由运行时提供，此处只需刷新倒计时。
      countdownTimer ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => _tickCountdown(),
      );
      _showFeedback(
        status: purpose == EmailCodePurpose.registration
            ? '验证码已发送，请查收邮件。'
            : '验证码发送成功',
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  /// 校验输入并提交当前认证流程。
  Future<void> _httpSubmitAuth() async {
    if (busy) return;
    _showFeedback();

    /// 本次认证使用的邮箱地址。
    final address = _readEmail();
    if (address == null) return;

    /// 验证码按字符串提交，保留前导零。
    final code = codeController.text;

    /// 发送给后端的密码，保留用户输入的首尾字符。
    final password = passwordController.text;

    /// 仅注册或重置流程使用的确认密码。
    final confirmPassword = confirmController.text;
    if (mode.codePurpose != null && !RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      _showFeedback(error: '请输入六位数字验证码');
      return;
    }
    if (mode != AuthMode.code && password.trim().isEmpty) {
      _showFeedback(error: isLogin ? '请输入密码' : '请输入新密码');
      return;
    }
    if (!isLogin) {
      /// Java 按 Unicode 码点计算的新密码长度。
      final length = password.runes.length;
      if (length < 8 || length > 16) {
        _showFeedback(error: '密码长度应为 8 至 16 个字符');
        return;
      }
      if (password != confirmPassword) {
        _showFeedback(error: '两次输入的密码不一致');
        return;
      }
    }
    FocusScope.of(context).unfocus();
    setState(() => submitting = true);

    try {
      /// 普通登录和注册返回用户资料及令牌，重置密码后需重新登录。
      final result = switch (mode) {
        AuthMode.password => await authApi.loginWithPassword(address, password),
        AuthMode.code => await authApi.loginWithCode(address, code),
        AuthMode.register => await authApi.register(
          address,
          code,
          password,
          confirmPassword,
        ),
        AuthMode.reset => null,
      };
      if (result == null) {
        /// 密码重置成功后切回登录表单。
        final resetResult = await authApi.resetPassword(
          address,
          code,
          password,
          confirmPassword,
        );
        if (!mounted || resetResult is! ApiSuccessModel<void>) return;
        setState(() => submitting = false);
        _changeMode(AuthMode.password);
        _showFeedback(status: '密码已重置，请使用新密码登录。');
        return;
      }

      if (!mounted || result is! ApiSuccessModel<EmailAuthResultModel>) return;
      if (!await _saveUserInfo(result.data) || !mounted) return;
      if (isLogin) {
        /// 登录成功提示展示并等待返回首页的时长。
        const successDuration = Duration(seconds: 1);
        AppToast.show('登录成功', duration: successDuration);
        await Future<void>.delayed(successDuration);
      }
      if (mounted && ModalRoute.of(context)?.isCurrent == true) _goBack();
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  /// 保存认证成功返回的 [result]，并提示本地存储错误。
  Future<bool> _saveUserInfo(EmailAuthResultModel result) async {
    try {
      await UserStore.shared.update(result.userInfo, result.token);
      return true;
    } on PlatformException {
      AppLogger.info('保存用户信息失败');
      if (mounted) _showFeedback(error: '无法保存用户信息，请重试');
      return false;
    }
  }

  /// 绘制安全区域内可滚动的认证页，[context] 提供屏幕尺寸。
  @override
  Widget build(BuildContext context) {
    /// 大屏使用更宽的卡片内边距。
    final wide = MediaQuery.sizeOf(context).width >= 600;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, wide ? 42 : 20, 16, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 466),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 22),
                  _buildAuthCard(wide),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 绘制导航返回和品牌标识。
  Widget _buildHeader() {
    return Row(
      children: [
        IconButton.outlined(
          onPressed: busy ? null : _goBack,
          tooltip: '返回',
          style: IconButton.styleFrom(
            foregroundColor: inkColor,
            backgroundColor: Colors.white,
            side: const BorderSide(color: lineColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.arrow_back, size: 18),
        ),
        const SizedBox(width: 12),
        Container(
          width: 31,
          height: 31,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.grid_view_rounded,
            size: 17,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          '百宝箱',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: inkColor,
          ),
        ),
      ],
    );
  }

  /// 绘制当前表单和流程入口，[wide] 表示是否使用大屏内边距。
  Widget _buildAuthCard(bool wide) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        wide ? 36 : 22,
        wide ? 34 : 28,
        wide ? 36 : 22,
        20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: lineColor),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12212B47),
            blurRadius: 48,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              mode.title,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: inkColor,
                height: 1.23,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mode.description,
            style: const TextStyle(
              fontSize: 14,
              color: secondaryColor,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 22),
          if (isLogin) ...[_buildLoginSwitch(), const SizedBox(height: 18)],
          AutofillGroup(child: _buildFields()),
          if (errorMessage.isNotEmpty || statusMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildFeedback(),
          ],
          const SizedBox(height: 18),
          _buildSubmitButton(),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (isLogin)
                const Text(
                  '还没有账号？',
                  style: TextStyle(color: secondaryColor, fontSize: 14),
                ),
              _buildTextAction(
                isLogin ? '立即注册' : '返回登录',
                () => _changeMode(
                  isLogin ? AuthMode.register : AuthMode.password,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 绘制两种邮箱登录方式的切换入口。
  Widget _buildLoginSwitch() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _buildSwitchButton('密码登录', AuthMode.password)),
          const SizedBox(width: 4),
          Expanded(child: _buildSwitchButton('验证码登录', AuthMode.code)),
        ],
      ),
    );
  }

  /// 将 [label] 显示为切换至 [targetMode] 的按钮。
  Widget _buildSwitchButton(String label, AuthMode targetMode) {
    /// 该按钮是否代表当前表单。
    final selected = mode == targetMode;
    return Semantics(
      selected: selected,
      child: TextButton(
        onPressed: busy ? null : () => _changeMode(targetMode),
        style: TextButton.styleFrom(
          backgroundColor: selected ? Colors.white : null,
          foregroundColor: selected ? accentColor : secondaryColor,
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }

  /// 绘制当前流程需要的邮箱、验证码及密码字段。
  Widget _buildFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFieldLabel('邮箱地址'),
        TextField(
          controller: emailController,
          enabled: !busy,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          inputFormatters: [LengthLimitingTextInputFormatter(320)],
          decoration: _buildInputDecoration('请输入邮箱地址'),
          // 邮箱变化后更新发码区显示的等待时间。
          onChanged: (_) => setState(() {}),
        ),
        if (mode.codePurpose != null) ...[
          const SizedBox(height: 15),
          _buildFieldLabel('邮箱验证码'),
          _buildCodeField(),
        ],
        if (mode != AuthMode.code) ...[
          const SizedBox(height: 15),
          _buildPasswordField(confirmation: false),
        ],
        if (!isLogin) ...[
          const SizedBox(height: 15),
          _buildPasswordField(confirmation: true),
        ],
      ],
    );
  }

  /// 绘制可保留前导零的验证码输入和重新发送操作。
  Widget _buildCodeField() {
    /// 当前流程剩余重发等待时间。
    final seconds = remainingSeconds;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: codeController,
            enabled: !busy,
            keyboardType: TextInputType.number,
            textInputAction: isLogin
                ? TextInputAction.done
                : TextInputAction.next,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: _buildInputDecoration('六位数字'),
            // 已完成登录表单时允许使用键盘提交。
            onSubmitted: isLogin ? (_) => _httpSubmitAuth() : null,
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: busy || seconds > 0 ? null : _httpSendCode,
          style: OutlinedButton.styleFrom(
            foregroundColor: accentColor,
            side: const BorderSide(color: lineColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: const Size(110, 50),
            padding: const EdgeInsets.symmetric(horizontal: 9),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          child: Text(
            sending
                ? '发送中…'
                : seconds > 0
                ? '$seconds 秒后重发'
                : '获取验证码',
          ),
        ),
      ],
    );
  }

  /// 绘制密码输入，[confirmation] 表示是确认密码而非主密码。
  Widget _buildPasswordField({required bool confirmation}) {
    /// 当前密码输入框的明文显示状态。
    final visible = confirmation ? confirmationVisible : passwordVisible;

    /// 当前输入框旁展示的名称。
    final label = confirmation
        ? '确认新密码'
        : isLogin
        ? '密码'
        : '新密码';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mode == AuthMode.password)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFieldLabel(label),
              _buildTextAction(
                '忘记密码？',
                () => _changeMode(AuthMode.reset),
                compact: true,
              ),
            ],
          )
        else
          _buildFieldLabel(label),
        TextField(
          controller: confirmation ? confirmController : passwordController,
          enabled: !busy,
          obscureText: !visible,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: confirmation
              ? null
              : [isLogin ? AutofillHints.password : AutofillHints.newPassword],
          textInputAction: isLogin || confirmation
              ? TextInputAction.done
              : TextInputAction.next,
          inputFormatters: [
            LengthLimitingTextInputFormatter(isLogin ? 256 : 32),
          ],
          decoration:
              _buildInputDecoration(
                confirmation
                    ? '请再次输入新密码'
                    : isLogin
                    ? '请输入密码'
                    : '8 至 16 个字符',
              ).copyWith(
                suffixIcon: IconButton(
                  tooltip: visible ? '隐藏$label' : '显示$label',
                  onPressed: busy ? null : () => _togglePassword(confirmation),
                  icon: Icon(
                    visible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: secondaryColor,
                    size: 19,
                  ),
                ),
              ),
          // 完成登录或确认密码输入时可以直接提交表单。
          onSubmitted: isLogin || confirmation
              ? (_) => _httpSubmitAuth()
              : null,
        ),
      ],
    );
  }

  /// 切换密码可见性，[confirmation] 指定是否操作确认密码框。
  void _togglePassword(bool confirmation) {
    setState(() {
      if (confirmation) {
        confirmationVisible = !confirmationVisible;
      } else {
        passwordVisible = !passwordVisible;
      }
    });
  }

  /// 绘制输入框上方的 [label]。
  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: inkColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 生成统一的输入框样式及 [hint]。
  InputDecoration _buildInputDecoration(String hint) {
    /// 输入框在不同交互状态下共用的圆角。
    final radius = BorderRadius.circular(12);
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 15),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      constraints: const BoxConstraints(minHeight: 50),
      border: OutlineInputBorder(borderRadius: radius),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: lineColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: accentColor, width: 1.5),
      ),
    );
  }

  /// 绘制触发 [onPressed] 的文字按钮，[compact] 用于表单标签行。
  Widget _buildTextAction(
    String label,
    VoidCallback onPressed, {
    bool compact = false,
  }) {
    return TextButton(
      onPressed: busy ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: accentColor,
        padding: compact
            ? const EdgeInsets.only(bottom: 7, left: 6)
            : const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: compact ? Size.zero : const Size(0, 40),
        tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }

  /// 在表单内显示可被屏幕阅读器读出的错误或成功信息。
  Widget _buildFeedback() {
    /// 当前反馈是否需要使用错误色。
    final isError = errorMessage.isNotEmpty;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isError ? const Color(0xFFFFF1F2) : const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          isError ? errorMessage : statusMessage,
          style: TextStyle(
            color: isError ? const Color(0xFF9F1239) : const Color(0xFF14532D),
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  /// 绘制提交按钮及等待请求完成的进度指示。
  Widget _buildSubmitButton() {
    return FilledButton(
      onPressed: busy ? null : _httpSubmitAuth,
      style: FilledButton.styleFrom(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: submitting
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                semanticsLabel: '正在提交',
              ),
            )
          : Text(mode.action),
    );
  }
}
