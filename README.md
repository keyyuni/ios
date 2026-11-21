# 农场助手 · iOS 版（Flutter 重写）

把 [ccpopy/farm-mobile](https://github.com/ccpopy/farm-mobile) 这个 **原生 Android（Kotlin + Jetpack Compose）** 客户端，重写为可以打包成 **iOS IPA** 的 Flutter 工程，并对接同一个自建服务端 [liyangpengs/qq-farm-bot](https://github.com/liyangpengs/qq-farm-bot)。

> **为什么要重写而不是转换**：原项目是 Kotlin + Compose + androidx 依赖，无法编译成 iOS 二进制。iOS 侧能跑的是 Swift / Objective-C / Flutter / React Native / Compose Multiplatform。本工程选 Flutter，理由见文末「技术选型」。

---

## 一、三步出包（不需要 Mac）

iOS 编译必须有 macOS + Xcode，所以借用 GitHub Actions 的 macOS 机器。

**第 1 步：代码推送到仓库**

代码已在 <https://github.com/keyyuni/ios>，推送即自动触发构建。后续改动只需：

```bash
git add . && git commit -m "改动说明" && git push
```

**第 2 步：等 Actions 跑完**

推送后自动触发 `build-ios-ipa` 工作流（也可以在仓库 Actions 页面点 `Run workflow` 手动触发）。首次构建约 10–15 分钟，主要耗在 Flutter SDK 缓存和 CocoaPods。

**第 3 步：下载 IPA**

Actions → 对应那次运行 → 页面底部 **Artifacts** → 下载 `farm-ios-ipa.zip`，解压得到 `farm-ios-unsigned.ipa`。

这个包是**未签名**的，装不进普通 iPhone，但你的设备支持 TrollStore / 越狱，正好可以直接装。

---

## 二、装到手机

### 方案 A：TrollStore（你的情况，推荐）

1. 把 `farm-ios-unsigned.ipa` 传到手机上（AirDrop、iCloud Drive、或者用 Filza 通过局域网共享都可以）。
2. 打开 **TrollStore** → 右上角 **+** → 选择这个 IPA。
3. 等待安装完成，桌面出现「农场助手」。
4. 直接打开即可，TrollStore 安装的应用**永久有效**，不需要 7 天重签，也不会掉签。

> TrollStore 会绕过系统的签名校验（CoreTrust），所以未签名 IPA 能直接装。前提是 TrollStore 本身在你设备的系统版本上可用。

### 方案 B：越狱设备手动安装

```bash
# 在越狱设备上（NewTerm / SSH）
unzip farm-ios-unsigned.ipa
ldid -S Payload/Runner.app/Runner          # 伪签名，越狱环境下系统不校验
cp -r Payload/Runner.app /Applications/
uicache -a                                  # 刷新图标缓存
```

或者用 Filza 把 `Payload/Runner.app` 直接拖进 `/Applications/`，再执行 `uicache -a`。

### 方案 C：没有 TrollStore 也没越狱（备选）

用 **Sideloadly**（Windows/macOS 都行）配合你的 Apple ID 自签：

1. 安装 iTunes（Windows 版，提供驱动）→ 装 Sideloadly。
2. 数据线连 iPhone，把 IPA 拖进 Sideloadly，填 Apple ID。
3. 点 Start，输入 Apple ID 密码（用于生成免费证书）。
4. iPhone 上：设置 → 通用 → VPN与设备管理 → 信任该开发者。
5. 限制：**7 天到期**，最多同时 3 个自签 App，到期需重签。

---

## 三、首次打开怎么配

1. 应用启动后进入「连接你的农场服务」页。
2. 填服务器地址，例如 `http://192.168.1.10:3000` 或 `https://farm.example.com`，点**测试连接**。
   - 首次访问局域网会弹「允许访问本地网络」，必须点允许，否则连不上。
3. 选授权方式：
   - **账号密码**：和网页管理面板同一个管理员账号，服务端重启后重新登录即可。
   - **会话 Token**：直接从网页面板复制 `x-admin-token`，适合不想反复登录的场景。
4. 登录成功后自动拉账号列表、连上 Socket.IO 实时通道，进入「总览」。

---

## 四、当前进度

| 模块 | 状态 | 说明 |
|---|---|---|
| 连接 / 密码登录 / Token 授权 | ✅ | 含连接测试、凭证失效自动踢回登录页 |
| 多账号切换 | ✅ | 顶部下拉，切号会清空旧数据避免串号 |
| 总览（状态 / 资产 / 会话统计 / 日志流） | ✅ | Socket 实时刷新，日志保留最近 300 条 |
| 农场工作台（3 列宫格 / 倒计时 / 单块操作） | ✅ | 操作类型严格对齐服务端 `all/harvest/clear/plant/upgrade` |
| 一键收获 / 护理 / 种植 / 施肥 | ✅ | 施肥类型 `normal` / `organic` |
| 施肥购买、日志清空、账号启停 | ✅ | |
| 牧场工作台 | 🚧 接口已就绪 | 界面待接入（动物 / 设施 / 背包 / 任务 / 图鉴） |
| 好友互动 | 🚧 接口已就绪 | 界面待接入 |
| 发现中心（活动 / 商城 / 节令） | 🚧 接口已就绪 | 界面待接入 |
| 推送通知 | ⬜ 计划中 | iOS 侧需处理通知权限与后台限制 |

> 接口层（`lib/data/api_client.dart`）已覆盖原版约 70 个 REST 端点，后续接界面不用再补网络代码。

---

## 五、目录结构

```
farm_ios/
├── pubspec.yaml                    依赖声明
├── analysis_options.yaml
├── .github/workflows/
│   └── ios-unsigned.yml            macOS 云端构建 + 打未签名 IPA
└── lib/
    ├── main.dart                   入口，注入全局 Controller
    ├── app.dart                    根组件 + 启动/未授权/已授权三态路由
    ├── core/
    │   ├── json.dart               容错 JSON 读取（对应原版 optXxxFlex 系列）
    │   ├── format.dart             数字缩写、倒计时、时间格式化
    │   └── theme.dart              Material 3 主题与间距常量
    ├── data/
    │   ├── api_client.dart         70+ 端点，三档超时
    │   ├── socket_manager.dart     Socket.IO 实时通道
    │   └── models/                 状态 / 土地 / 背包 / 账号 / 日志
    ├── state/
    │   └── app_controller.dart     会话 + 数据 + 操作 的统一状态中枢
    └── ui/
        ├── shell.dart              5 标签主壳 + 账号切换 + 全局提示
        └── pages/                  连接 / 总览 / 农场 / 发现 / 好友 / 我的
```

---

## 六、本地开发（可选，需要 Mac）

```bash
flutter --version          # 建议 3.22 以上
flutter pub get
flutter create --platforms=ios --org io.github.ccpopy --project-name farm_ios .
flutter run -d <你的设备>
```

`ios/` 目录是构建时由 `flutter create` 生成的，不放进版本库——省得手写上千行 `project.pbxproj` 出错。真要在本地调试，执行上面第三条命令即可生成。

---

## 七、与原版的行为对齐说明

这些细节是照抄原版实现，改动前请先确认服务端行为：

1. **浇水 / 除草 / 除虫不是独立操作**，服务端统一走 `opType: "clear"`。
2. **只有 `clear` 会带 `landId`**，`harvest` / `plant` / `all` / `upgrade` 都是全场地操作。所以单块地的「收获」按钮实际会收获全部成熟作物，界面上已标注为「收获（全部成熟）」。
3. **牧场消费类操作需要二次确认**：先 `POST /api/ranch/{action}/quote` 拿 `signature`，再带 `expected.signature` 提交。
4. **`/api/settings/save` 返回 202 表示部分成功**，不能当错误处理。
5. **Socket 连上后必须 `emit('subscribe', {accountId})`** 才会收到该账号推送，accountId 为空时传 `all`。

---

## 八、常见报错

| 报错 | 原因与处理 |
|---|---|
| `CocoaPods not installed` | Actions 的 macOS 镜像自带，本地开发才需要 `sudo gem install cocoapods` |
| `cmdline-tools not found` | 这是 Android 侧报错，iOS 构建不受影响 |
| `Provisioning profile doesn't match` | 说明用了签名构建；本工程用 `--no-codesign`，不该出现 |
| 装好后打开闪退 | 多为 ATS 拦截或 Socket 连接异常，先检查 Info.plist 是否被覆盖（工作流里有 `plutil -p` 输出可核对） |
| 连接页一直转圈 | 服务器地址漏了端口，或局域网权限被拒绝（设置 → 隐私 → 本地网络） |

---

## 九、技术选型说明

**为什么是 Flutter，而不是把 Kotlin 直接迁到 Compose Multiplatform？**

| 方案 | 代码复用 | 风险 |
|---|---|---|
| Flutter | 0%（业务逻辑重写，但接口契约照抄） | 低，生态成熟，`socket_io_client` 稳定 |
| Compose Multiplatform | 约 60% UI | 高：`io.socket:socket.io-client` 是 JVM 库，iOS 无等价实现；`androidx.*` 全量替换；导航、DataStore 都要换 |

结论：只做 iOS 一端、且要保证能打包成功，Flutter 是更稳的路径。若将来想同时维护 Android 与 iOS，可以直接用本工程同时出两个平台。

---

## 十、免责说明

- 本工程基于公开仓库的接口契约重写，**仅用于个人自建服务的客户端使用**，请勿分发构建产物。
- 原仓库未声明 LICENSE，二次分发存在版权风险。
- 该客户端用于游戏自动化，使用后果（含账号风险）由使用者自行承担。
