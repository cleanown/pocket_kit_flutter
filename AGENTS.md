### 开发规范

1. 所有生成的变量，方法，组件都要有中文注释说明
2. 文件命名统一使用蛇形命名
3. 公共组件统一使用"Build+大驼峰"命名，例：BuildCommonHeader
4. 页面组件统一使用"_build+大驼峰"命名，例：_buildUserCenter
5. 页面网络请求统一使用"_http+大驼峰"命名，例：_httpGetUserInfo
6. 页面普通方法统一使用"_+驼峰"命名，例：_changeTab
7. 页面类统一使用大驼峰，例：OrderPage
8. 页面变量必须使用不带前导下划线的小驼峰命名（lowerCamelCase），适用于页面 Widget、State 中的字段、局部变量及方法参数。
    - 正确示例：loadingProgress、webViewController、formKey、urlController。
    - 错误示例：_loadingProgress、_webViewController、LoadingProgress、loading_progress。
    - 即使变量只在当前页面内部使用，也不允许以 Dart 私有成员惯例为由添加 `_` 前缀。
    - 变量与方法的命名规则分开执行：变量使用 loadingProgress；普通方法使用 _updateProgress；页面组件方法使用 _buildLoadingIndicator。
    - 以上限制针对自行定义的变量；Flutter/Dart 必须保留的外部 API 名称不作修改。类名按第 7 条执行。
9. 图片资源统一放在assets/images/内，命名要合适，避免其他模块图片冲突
10. 禁止自动提交代码，所有代码都需要人工检查，人工提交
### 最终声明
```
该规范适用于整个项目，不论是新增还是修改
```