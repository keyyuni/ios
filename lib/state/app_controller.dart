import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_client.dart';
import '../data/models/account.dart';
import '../data/models/bag.dart';
import '../data/models/land.dart';
import '../data/models/log_entry.dart';
import '../data/models/status_snapshot.dart';
import '../data/socket_manager.dart';

/// 全局状态中枢：会话 + 实时数据 + 农场操作。
///
/// 拆分说明：安卓版把状态放在 AppSessionViewModel + 各 Screen 里，
/// 这里合成一个 Controller，页面只读它，避免跨页面数据不同步。
class AppController extends ChangeNotifier {
  final FarmApiClient api = FarmApiClient();
  final RealtimeSocket socket = RealtimeSocket();

  // ---------------- 会话
  String serverUrl = '';
  String token = '';
  String username = '';
  String accountId = '';
  /// password / token
  String authMode = 'password';
  bool initializing = true;

  List<AccountItem> accounts = const [];
  bool accountsLoading = false;

  // ---------------- 实时数据
  StatusSnapshot? status;
  LandsPayload? lands;
  BagPayload? bag;
  int diamond = 0;
  List<RunLogEntry> logs = const [];
  bool statusLoading = false;
  bool landsLoading = false;
  bool realtimeConnected = false;

  /// 一次性提示，页面消费后调用 clearNotice
  String? notice;

  bool get isAuthed => token.isNotEmpty && serverUrl.isNotEmpty;
  bool get hasAccount => accountId.isNotEmpty;

  AccountItem? get currentAccount {
    for (final a in accounts) {
      if (a.id == accountId) return a;
    }
    return accounts.isEmpty ? null : accounts.first;
  }

  AppController() {
    socket.onConnectionChanged = (c) {
      realtimeConnected = c;
      notifyListeners();
    };
    socket.onStatus = (accId, snap) {
      if (accId != accountId) return;
      status = snap;
      statusLoading = false;
      notifyListeners();
    };
    socket.onNewLog = (entry) {
      if (entry.accountId.isNotEmpty && accountId.isNotEmpty && entry.accountId != accountId) {
        return;
      }
      final next = [...logs, entry];
      logs = next.length > 300 ? next.sublist(next.length - 300) : next;
      notifyListeners();
    };
    socket.onLogSnapshot = (accId, list) {
      if (accId != accountId && !(accId == 'all' && accountId.isEmpty)) return;
      logs = list.length > 300 ? list.sublist(list.length - 300) : list;
      notifyListeners();
    };
    socket.onAccountLog = (ev) {
      if (ev.isFailure) {
        notice = '账号 ${ev.accountName.isEmpty ? ev.accountId : ev.accountName} 登录异常：${ev.message}';
        notifyListeners();
      }
    };

    api.onUnauthorized = () {
      // token 失效，直接清理本地会话
      unawaited(_clearAuth());
    };
  }

  // ================================================================ 启动

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    // 旧版本可能把 /login 这类页面路径一起存了进来，读取时顺手洗一遍
    final savedUrl = prefs.getString('serverUrl') ?? '';
    serverUrl = FarmApiClient.normalizeBaseUrl(savedUrl) ?? savedUrl;
    token = prefs.getString('token') ?? '';
    username = prefs.getString('username') ?? '';
    accountId = prefs.getString('accountId') ?? '';
    authMode = prefs.getString('authMode') ?? 'password';
    initializing = false;
    notifyListeners();

    if (!isAuthed) return;
    api.setSession(serverUrl: serverUrl, token: token, accountId: accountId);
    await _startSession();
  }

  /// 已有 token 时的启动流程：校验 → 拉账号 → 连 Socket → 拉数据
  Future<void> _startSession() async {
    try {
      final valid = await api.validateToken(serverUrl, token);
      if (!valid) {
        await _clearAuth();
        notice = '登录凭证已失效，请重新授权';
        notifyListeners();
        return;
      }
    } on ApiException catch (e) {
      notice = e.message;
      notifyListeners();
    }

    await refreshAccounts();
    if (accountId.isEmpty && accounts.isNotEmpty) {
      await selectAccount(accounts.first.id);
    }
    socket.connect(serverUrl: serverUrl, token: token, accountId: accountId);
    await refreshAll();
  }

  // ================================================================ 登录

  /// 测试服务器连通性，成功返回版本号，失败抛 ApiException
  Future<String> testServer(String rawUrl) async {
    final info = await api.fetchGameVersion(rawUrl);
    return info.version.isEmpty ? '连接成功' : '连接成功（${info.version}）';
  }

  /// 管理员账号密码登录。成功返回 null，失败返回错误文案。
  Future<String?> connectWithPassword(String rawUrl, String user, String pass) async {
    final normalized = FarmApiClient.normalizeBaseUrl(rawUrl);
    if (normalized == null) return '请输入有效的服务器地址，例如 https://farm.example.com';
    if (user.trim().isEmpty || pass.isEmpty) return '请输入管理员用户名和密码';

    try {
      final result = await api.login(normalized, user.trim(), pass);
      if (!result.ok) return result.friendlyError;

      serverUrl = normalized;
      token = result.token;
      username = result.username.isEmpty ? user.trim() : result.username;
      authMode = 'password';
      accountId = '';
      await _persist();
      api.setSession(serverUrl: serverUrl, token: token, accountId: accountId);
      await _startSession();
      return result.mustChangePassword ? '登录成功，建议在网页端修改默认密码' : null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// 直接粘贴 Web 面板的 x-admin-token 授权
  Future<String?> connectWithToken(String rawUrl, String rawToken) async {
    final normalized = FarmApiClient.normalizeBaseUrl(rawUrl);
    if (normalized == null) return '请输入有效的服务器地址';
    final t = rawToken.trim();
    if (t.isEmpty) return '请输入 API Token';

    try {
      final valid = await api.validateToken(normalized, t);
      if (!valid) return 'Token 验证失败';
      String name = 'API 用户';
      try {
        final me = await api.fetchUserMe(normalized, t);
        if (me.isNotEmpty) name = me;
      } catch (_) {
        // 取用户名失败不影响登录
      }

      serverUrl = normalized;
      token = t;
      username = name;
      authMode = 'token';
      accountId = '';
      await _persist();
      api.setSession(serverUrl: serverUrl, token: token, accountId: accountId);
      await _startSession();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> logout() async {
    if (authMode == 'password') {
      try {
        await api.logout();
      } catch (_) {
        // 服务端不可达也要允许本地退出
      }
    }
    await _clearAuth();
    notice = '已退出当前服务器授权';
    notifyListeners();
  }

  Future<void> _clearAuth() async {
    token = '';
    accountId = '';
    status = null;
    lands = null;
    bag = null;
    logs = const [];
    accounts = const [];
    diamond = 0;
    socket.disconnect();
    api.clearSession();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('serverUrl', serverUrl);
    await prefs.setString('token', token);
    await prefs.setString('username', username);
    await prefs.setString('accountId', accountId);
    await prefs.setString('authMode', authMode);
  }

  // ================================================================ 账号

  Future<void> refreshAccounts() async {
    if (!isAuthed) return;
    accountsLoading = true;
    notifyListeners();
    try {
      final list = await api.fetchAccounts();
      accounts = list;
      // 当前账号不在列表里就回退到第一个
      if (list.isNotEmpty && !list.any((a) => a.id == accountId)) {
        accountId = list.first.id;
        api.setAccountId(accountId);
        await _persist();
      }
    } on ApiException catch (e) {
      notice = e.message;
    } finally {
      accountsLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectAccount(String id) async {
    if (id == accountId) return;
    accountId = id;
    api.setAccountId(id);
    // 切账号必须清空旧数据，否则会串号显示
    status = null;
    lands = null;
    bag = null;
    logs = const [];
    await _persist();
    socket.subscribeAccount(id);
    notifyListeners();
    await refreshAll();
  }

  Future<String?> startAccount(String id) async {
    try {
      await api.startAccount(id);
      await refreshAccounts();
      if (id == accountId) await refreshStatus();
      return '已发送启动指令';
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> stopAccount(String id) async {
    try {
      await api.stopAccount(id);
      await refreshAccounts();
      if (id == accountId) await refreshStatus();
      return '已停止账号';
    } on ApiException catch (e) {
      return e.message;
    }
  }

  // ================================================================ 数据刷新

  Future<void> refreshAll() async {
    if (!hasAccount) return;
    await Future.wait([refreshStatus(), refreshLands(), refreshBag()]);
  }

  Future<void> refreshStatus() async {
    if (!hasAccount) return;
    statusLoading = true;
    notifyListeners();
    try {
      final snap = await api.fetchStatus(accountId);
      status = snap;
      try {
        logs = await api.fetchLogs(limit: 120);
      } catch (_) {
        // 日志失败不影响状态展示
      }
      try {
        diamond = await api.fetchDiamond();
      } catch (_) {}
    } on ApiException catch (e) {
      notice = e.message;
    } finally {
      statusLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshLands() async {
    if (!hasAccount) return;
    landsLoading = true;
    notifyListeners();
    try {
      lands = await api.fetchLands();
    } on ApiException catch (e) {
      notice = e.message;
    } finally {
      landsLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshBag() async {
    if (!hasAccount) return;
    try {
      bag = await api.fetchBag();
      notifyListeners();
    } on ApiException catch (e) {
      notice = e.message;
      notifyListeners();
    }
  }

  // ================================================================ 农场操作

  /// op 只能是 all / harvest / clear / plant / upgrade
  Future<String?> farmOp(String op, {int? landId}) async {
    if (!hasAccount) return '请先选择账号';
    try {
      final data = await api.operateFarm(op, landId: landId);
      await refreshLands();
      await refreshStatus();
      return _resultMessage(data) ?? _opLabel(op);
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> fertilizeAll(String type) async {
    if (!hasAccount) return '请先选择账号';
    try {
      final data = await api.fertilizeAll(type);
      await refreshLands();
      await refreshBag();
      return _resultMessage(data) ?? '已施${type == 'organic' ? '有机' : '普通'}肥';
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> fertilizeLand(int landId, String type) async {
    if (!hasAccount) return '请先选择账号';
    try {
      final data = await api.fertilizeLand(landId, type);
      await refreshLands();
      return _resultMessage(data) ?? '已施肥';
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> buyFertilizer(String type, int count) async {
    try {
      await api.buyFertilizer(type, count);
      await refreshBag();
      return '已购买 $count 个${type == 'organic' ? '有机' : '普通'}化肥';
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> clearLogs() async {
    try {
      await api.clearLogs();
      logs = const [];
      notifyListeners();
      return '日志已清空';
    } on ApiException catch (e) {
      return e.message;
    }
  }

  String _opLabel(String op) {
    switch (op) {
      case 'all':
        return '已触发一键全自动';
      case 'harvest':
        return '已收获';
      case 'clear':
        return '已清理';
      case 'plant':
        return '已种植';
      case 'upgrade':
        return '已升级';
      default:
        return '操作已提交';
    }
  }

  /// 服务端可能返回 { ok, message } / { success } / 纯文本，统一取一句提示
  String? _resultMessage(dynamic data) {
    if (data is Map) {
      final msg = data['message'] ?? data['error'] ?? data['msg'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    }
    if (data is String && data.trim().isNotEmpty && data.length < 100) return data.trim();
    return null;
  }

  void clearNotice() {
    notice = null;
  }

  @override
  void dispose() {
    socket.disconnect();
    super.dispose();
  }
}
