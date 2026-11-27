import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_kit_flutter/core/auth/user_info_model.dart';
import 'package:pocket_kit_flutter/core/auth/user_store.dart';
import 'package:pocket_kit_flutter/core/network/api_client.dart';
import 'package:pocket_kit_flutter/core/shared/app_toast.dart';
import 'package:pocket_kit_flutter/features/home/pages/home_page.dart';
import 'package:pocket_kit_flutter/features/login/data/email_auth_api.dart';
import 'package:pocket_kit_flutter/features/login/pages/login_page.dart';

/// 验证页面对接七个 Java 邮箱认证接口，并正确保存已登录账号。
void main() {
  // 测试使用 Flutter 的安全存储模拟实现。
  TestWidgetsFlutterBinding.ensureInitialized();

  // tester 驱动认证页和首页的实际组件。
  testWidgets('认证表单使用对应的发码和提交地址，登录后显示账号', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});

    /// 跨流程保留的测试邮箱。
    const email = 'test@example.com';

    /// 首位为零的邮件验证码。
    const code = '012345';

    /// 测试用密码，验证提交保留首尾空格。
    const password = '  密码验证 pass 🔑  ';

    /// 旧账号可能使用超过 16 个字符的密码。
    const existingPassword = '  密码验证 password  ';

    /// 按发生顺序收集页面请求，校验接口及请求字段。
    final requests = <RequestOptions>[];

    /// 在统一网络层提供可控的 Java 格式响应。
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          // options 为页面实际提交的请求，handler 返回测试响应。
          onRequest: (options, handler) {
            requests.add(options);

            /// 是否为成功后应返回令牌的登录接口。
            final login =
                options.path.endsWith('/login') ||
                options.path.endsWith('/login/password');

            /// 登录和注册共用的测试凭据。
            const token = {
              'userId': 42,
              'accessToken': 'test-token',
              'tokenType': 'Bearer',
              'expiresIn': 600,
            };

            /// 根据接口返回普通登录凭据或注册结果。
            final data = switch (options.path) {
              '/api/app/auth/email/register' => {
                'user': {
                  'id': 42,
                  'email': email,
                  'nickname': '测试昵称',
                  'avatarUrl': 'https://example.com/avatar.png',
                },
                'token': token,
              },
              _ when login => token,
              _ => null,
            };
            handler.resolve(
              Response<Map<String, Object?>>(
                requestOptions: options,
                statusCode: 200,
                data: {'code': 200, 'message': '成功', 'data': data},
              ),
            );
          },
        ),
      );

    /// 用同一个请求客户端验证各认证操作。
    final api = EmailAuthApi(client: ApiClient(dio: dio));

    /// 挂载真实的首页和认证页，校验登录后返回首页。
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomePage()),
        GoRoute(
          path: '/login',
          builder: (_, _) => LoginPage(api: api),
        ),
      ],
    );
    addTearDown(router.dispose);

    /// 点击带有 [text] 的操作，[settle] 控制是否等候全部动画结束。
    Future<void> tap(String text, {bool settle = true}) async {
      /// 当前交互的具体文字控件。
      final primaryAction = find.widgetWithText(FilledButton, text);

      /// 当前可交互控件，优先定位主要表单按钮。
      final target = primaryAction.evaluate().isNotEmpty
          ? primaryAction
          : find.text(text);
      await tester.ensureVisible(target);
      await tester.tap(target);
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    /// 写入当前表单的第 [index] 个字段为 [value]。
    Future<void> fill(int index, String value) async {
      await tester.enterText(find.byType(TextField).at(index), value);
    }

    await tester.pumpWidget(
      MaterialApp.router(builder: AppToast.buildHost, routerConfig: router),
    );
    await tap('登录');
    await tap('登录');
    expect(find.text('请输入有效的邮箱地址'), findsOneWidget);
    expect(requests, isEmpty);
    await fill(0, email);
    await tap('立即注册');
    await tap('获取验证码');
    expect(find.textContaining('秒后重发'), findsOneWidget);
    await fill(1, code);
    await fill(2, password);
    await fill(3, 'mismatch');
    await tap('注册');
    expect(find.text('两次输入的密码不一致'), findsOneWidget);

    /// 超过新密码长度上限的输入。
    const longPassword = '1234567890123456🔑';
    await fill(2, longPassword);
    await fill(3, longPassword);
    await tap('注册');
    expect(find.text('密码长度应为 8 至 16 个字符'), findsOneWidget);
    await fill(2, password);
    await fill(3, password);
    await tap('注册');
    expect(find.text(email), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
    expect(UserStore.shared.token, 'test-token');

    /// 检查注册结果实际写入的持久化数据。
    const storage = FlutterSecureStorage();
    expect(await storage.read(key: 'token'), 'test-token');
    expect(jsonDecode((await storage.read(key: 'userInfo'))!), {
      'id': '42',
      'email': email,
      'username': '测试昵称',
      'avatar': 'https://example.com/avatar.png',
      'account': '',
      'phone': null,
    });
    await UserStore.shared.init();
    expect(UserStore.shared.current.username, '测试昵称');
    await tap('退出登录');

    await tap('登录');
    await tap('忘记密码？');
    await fill(0, email);
    await tap('获取验证码');
    expect(find.text('验证码发送成功'), findsOneWidget);
    await fill(1, code);
    await fill(2, password);
    await fill(3, password);
    await tap('重置密码');
    expect(find.text('密码已重置，请使用新密码登录。'), findsOneWidget);
    await fill(1, existingPassword);
    await tap('登录', settle: false);
    expect(find.text('登录成功'), findsOneWidget);
    expect(find.byType(LoginPage), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text(email), findsOneWidget);
    await UserStore.shared.init();
    expect(UserStore.shared.current.id, '42');
    await tap('退出登录');
    expect(UserStore.shared.isLogin, isFalse);
    expect(UserStore.shared.token, isNull);
    expect(await storage.read(key: 'userInfo'), isNull);
    expect(await storage.read(key: 'token'), isNull);

    await tap('登录');
    await tap('验证码登录');
    await fill(0, email);
    await tap('获取验证码');
    expect(find.text('验证码发送成功'), findsOneWidget);
    await fill(1, code);
    await tap('登录', settle: false);
    expect(find.text('登录成功'), findsOneWidget);
    expect(find.byType(LoginPage), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text(email), findsOneWidget);
    await tap('退出登录');

    expect(requests.map((request) => request.path), [
      '/api/app/auth/email/register/code',
      '/api/app/auth/email/register',
      '/api/app/auth/email/password/reset/code',
      '/api/app/auth/email/password/reset',
      '/api/app/auth/email/login/password',
      '/api/app/auth/email/code',
      '/api/app/auth/email/login',
    ]);
    expect(requests[1].data, {
      'email': email,
      'code': code,
      'password': password,
      'confirmPassword': password,
    });
    expect(requests[3].data, requests[1].data);
    expect(requests[4].data, {'email': email, 'password': existingPassword});
    expect(requests[6].data, {'email': email, 'code': code});
  });

  // tester 驱动登录页，并检查网络层通过应用消息入口展示的提示。
  testWidgets('业务和 HTTP 错误统一提示，表单结束加载并允许重试', (tester) async {
    /// 模拟发码业务失败和登录 HTTP 失败的传输。
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          // request 为当前请求，handler 将对应的失败响应交给网络层。
          onRequest: (request, handler) {
            if (request.path.endsWith('/code')) {
              handler.resolve(
                Response<Map<String, Object?>>(
                  requestOptions: request,
                  statusCode: 200,
                  data: {'code': 1001, 'message': '验证码发送失败'},
                ),
              );
              return;
            }
            handler.reject(
              DioException.badResponse(
                statusCode: 401,
                requestOptions: request,
                response: Response<Map<String, Object?>>(
                  requestOptions: request,
                  statusCode: 401,
                  data: {'code': 401, 'message': '验证码不正确'},
                ),
              ),
            );
          },
        ),
      );
    addTearDown(() => dio.close(force: true));

    /// 登录页使用真实的 API 封装，仅替换传输。
    final api = EmailAuthApi(client: ApiClient(dio: dio));
    await tester.pumpWidget(
      MaterialApp(
        builder: AppToast.buildHost,
        home: LoginPage(api: api),
      ),
    );
    await tester.tap(find.text('验证码登录'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'test@example.com');

    /// 发码失败后仍可重新获取验证码。
    final sendButton = find.widgetWithText(OutlinedButton, '获取验证码');
    await tester.ensureVisible(sendButton);
    await tester.tap(sendButton);
    await tester.pumpAndSettle();
    expect(find.text('验证码发送失败'), findsOneWidget);
    expect(find.textContaining('秒后重发'), findsNothing);
    expect(tester.widget<OutlinedButton>(sendButton).onPressed, isNotNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('验证码发送失败'), findsNothing);

    await tester.enterText(find.byType(TextField).at(1), '012345');

    /// 提交失败后仍停留在登录页并可再次提交。
    final submitButton = find.widgetWithText(FilledButton, '登录');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    expect(find.text('验证码不正确'), findsOneWidget);
    expect(find.text('登录成功'), findsNothing);
    expect(tester.widget<FilledButton>(submitButton).onPressed, isNotNull);
  });

  test('启动时只从完整的用户资料和令牌恢复登录', () async {
    /// 使用新结构保存的用户资料。
    const userInfo = UserInfoModel(id: '42', email: 'test@example.com');

    FlutterSecureStorage.setMockInitialValues({
      'userInfo': jsonEncode(userInfo.toStorage()),
      'token': 'saved-token',
    });
    await UserStore.shared.init();
    expect(UserStore.shared.isLogin, isTrue);
    expect(UserStore.shared.current.id, '42');
    expect(UserStore.shared.token, 'saved-token');

    /// 用于模拟资料已写入、令牌尚未写入的安全存储。
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'token');
    await UserStore.shared.init();
    expect(UserStore.shared.isLogin, isFalse);
    expect(UserStore.shared.token, isNull);
  });

  test('启动时迁移旧版有效缓存，并跳过已过期缓存', () async {
    /// 旧版缓存中保存的邮箱。
    const email = 'legacy@example.com';

    /// 按指定到期时间 [expiresAt] 模拟旧版缓存。
    String legacyCache(DateTime expiresAt) => jsonEncode({
      'userId': 42,
      'email': email,
      'accessToken': 'legacy-token',
      'expiresAt': expiresAt.millisecondsSinceEpoch,
    });

    /// 用于构造有效和已过期的旧版缓存。
    final now = DateTime.now();

    /// 用于验证迁移后新旧键的持久化内容。
    const storage = FlutterSecureStorage();
    FlutterSecureStorage.setMockInitialValues({
      'pocket_kit_auth_session': legacyCache(now.add(const Duration(days: 1))),
    });
    await UserStore.shared.init();
    expect(UserStore.shared.isLogin, isTrue);
    expect(UserStore.shared.current.email, email);
    expect(await storage.read(key: 'token'), 'legacy-token');
    expect(jsonDecode((await storage.read(key: 'userInfo'))!)['id'], '42');
    expect(await storage.read(key: 'pocket_kit_auth_session'), isNull);
    await UserStore.shared.reset();

    FlutterSecureStorage.setMockInitialValues({
      'pocket_kit_auth_session': legacyCache(
        now.subtract(const Duration(days: 1)),
      ),
    });
    await UserStore.shared.init();
    expect(UserStore.shared.isLogin, isFalse);
    expect(await storage.read(key: 'userInfo'), isNull);
    expect(await storage.read(key: 'token'), isNull);
    expect(await storage.read(key: 'pocket_kit_auth_session'), isNull);
  });

  test('旧请求失效时保留新登录，当前请求失效时清除资料和令牌', () async {
    FlutterSecureStorage.setMockInitialValues({});

    /// 发出旧请求时使用的账号资料。
    const previousUser = UserInfoModel(id: '42', email: 'old@example.com');

    /// 新登录后用于发出请求的账号资料。
    const currentUser = UserInfoModel(id: '43', email: 'new@example.com');

    /// 用于确认失效的登录已从本地清除。
    const storage = FlutterSecureStorage();
    await UserStore.shared.update(previousUser, 'previous-token');
    await Future.wait([
      UserStore.shared.update(currentUser, 'current-token'),
      UserStore.shared.invalidate(previousUser),
    ]);
    expect(UserStore.shared.current.id, '43');
    expect(UserStore.shared.token, 'current-token');

    await UserStore.shared.invalidate(currentUser);
    expect(UserStore.shared.isLogin, isFalse);
    expect(await storage.read(key: 'userInfo'), isNull);
    expect(await storage.read(key: 'token'), isNull);
  });
}
