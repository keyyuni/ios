import '../../core/json.dart';

/// 运行日志（/api/logs 与 Socket 的 log:new）
class RunLogEntry {
  final String accountId;
  final int? timeMs;
  final String level;
  final String module;
  final String message;
  final bool isWarn;

  const RunLogEntry({
    required this.accountId,
    required this.timeMs,
    required this.level,
    required this.module,
    required this.message,
    required this.isWarn,
  });

  factory RunLogEntry.parse(dynamic raw) {
    final m = asMap(raw);
    final level = strOr(m['level'], 'info').toLowerCase();
    final ts = intOrNull(m['ts']) ??
        intOrNull(m['time']) ??
        intOrNull(m['createdAt']) ??
        intOrNull(m['timestamp']);

    // 服务端有的版本把时间给成秒，有的给毫秒，这里统一成毫秒
    int? normalized = ts;
    if (ts != null && ts > 0 && ts < 100000000000) normalized = ts * 1000;

    return RunLogEntry(
      accountId: strOr(m['accountId'], ''),
      timeMs: normalized,
      level: level,
      module: strOr(m['module'], ''),
      message: strOrNull(m['message']) ?? strOrNull(m['text']) ?? strOrNull(m['msg']) ?? '',
      isWarn: boolOr(m['isWarn'],
          level == 'warn' || level == 'warning' || level == 'error'),
    );
  }

  static List<RunLogEntry> parseList(dynamic raw) {
    return asList(raw).map((e) => RunLogEntry.parse(e)).toList();
  }
}

/// 账号登录状态事件（Socket 的 account-log:new），用于掉线提醒
class AccountLogEvent {
  final String accountId;
  final String accountName;
  final String type;
  final String message;
  final int? timeMs;

  const AccountLogEvent({
    required this.accountId,
    required this.accountName,
    required this.type,
    required this.message,
    required this.timeMs,
  });

  /// 是否是登录失效类事件
  bool get isFailure {
    final t = type.toLowerCase();
    return t.contains('kick') ||
        t.contains('offline') ||
        t.contains('expire') ||
        t.contains('disconnect') ||
        t.contains('error');
  }

  factory AccountLogEvent.parse(dynamic raw) {
    final m = asMap(raw);
    return AccountLogEvent(
      accountId: strOr(m['accountId'], ''),
      accountName: strOr(m['accountName'], ''),
      type: strOr(m['type'], ''),
      message: strOrNull(m['message']) ?? strOrNull(m['text']) ?? '',
      timeMs: intOrNull(m['time']) ?? intOrNull(m['ts']),
    );
  }
}
