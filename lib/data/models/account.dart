import '../../core/json.dart';

/// 服务器上的农场账号（对应 /api/accounts 列表项）
class AccountItem {
  final String id;
  final String name;
  final String platform;
  final String loginType;
  final String status;
  final bool online;
  final bool running;
  final String avatarUrl;
  final int level;
  final String remark;

  const AccountItem({
    required this.id,
    required this.name,
    required this.platform,
    required this.loginType,
    required this.status,
    required this.online,
    required this.running,
    required this.avatarUrl,
    required this.level,
    required this.remark,
  });

  /// 平台标签，QQ / 微信
  String get platformLabel {
    switch (platform.toLowerCase()) {
      case 'qq':
        return 'QQ';
      case 'wx':
      case 'wechat':
        return '微信';
      default:
        return platform.isEmpty ? '未知' : platform;
    }
  }

  factory AccountItem.parse(dynamic raw) {
    final m = asMap(raw);
    final status = strOr(m['status'], '');
    return AccountItem(
      id: strOr(m['id'], ''),
      name: strOr(m['name'], '未命名账号'),
      platform: strOr(m['platform'], ''),
      loginType: strOr(m['loginType'], ''),
      status: status,
      // 服务端不同版本字段名不同，多路兜底
      online: boolOr(m['online'], status == 'online' || status == 'running'),
      running: boolOr(m['running'], status == 'running' || status == 'online'),
      avatarUrl: strOr(m['avatarUrl'], ''),
      level: intOr(m['level'], 0),
      remark: strOr(m['remark'], ''),
    );
  }
}

/// 登录结果（POST /api/login）
class LoginResult {
  final bool ok;
  final String token;
  final String username;
  final bool mustChangePassword;
  final String error;
  /// locked / rate_limit / 其他
  final String errorType;
  final int remainingMs;

  const LoginResult({
    required this.ok,
    required this.token,
    required this.username,
    required this.mustChangePassword,
    required this.error,
    required this.errorType,
    required this.remainingMs,
  });

  factory LoginResult.parse(dynamic raw) {
    var m = asMap(raw);
    // 服务端把结果包在 data 里：{ok:true, data:{token, user:{username}, ...}}
    if (m['data'] is Map) m = asMap(m['data']);
    final user = m['user'] is Map ? asMap(m['user']) : const <String, dynamic>{};
    final token = strOr(m['token'], '');
    final okFlag = raw is Map && raw.containsKey('ok') ? boolOr(raw['ok'], false) : token.isNotEmpty;
    return LoginResult(
      ok: okFlag && token.isNotEmpty,
      token: token,
      username: strOr(m['username'], strOr(user['username'], '')),
      mustChangePassword: boolOr(m['mustChangePassword'], false),
      error: strOr(m['error'], ''),
      errorType: strOr(m['errorType'], ''),
      remainingMs: intOr(m['remainingMs'], 0),
    );
  }

  /// 把服务端的错误码翻译成中文提示，逻辑对齐安卓版
  String get friendlyError {
    if (errorType == 'locked') {
      final mins = ((remainingMs + 59999) ~/ 60000).clamp(1, 9999);
      return '$error（约 $mins 分钟后解锁）';
    }
    if (errorType == 'rate_limit') {
      final secs = ((remainingMs + 999) ~/ 1000).clamp(1, 9999);
      return '$error（$secs 秒后可重试）';
    }
    return error.isEmpty ? '登录失败' : error;
  }
}

/// 服务器版本信息（GET /api/game-version），用于连接测试
class ServerVersionInfo {
  final String version;
  final String raw;
  final dynamic payload;

  const ServerVersionInfo({required this.version, required this.raw, required this.payload});

  factory ServerVersionInfo.parse(dynamic raw) {
    final m = asMap(raw);
    final v = strOrNull(m['version']) ??
        strOrNull(m['gameVersion']) ??
        strOrNull(m['botVersion']) ??
        '';
    return ServerVersionInfo(version: v, raw: v, payload: raw);
  }
}
