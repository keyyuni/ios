import '../../core/json.dart';

/// 账号状态快照，对应安卓版 StatusSnapshot。
/// 字段名严格对照服务端 /api/status 的返回结构，不要改。
class StatusSnapshot {
  final String accountId;

  // status{}
  final String name;
  final int level;
  final int exp;
  final int gold;
  final int coupon;
  final int goldBean;
  final String avatarUrl;

  // connection{}
  final bool connected;

  // levelProgress{}
  final int levelExpCurrent;
  final int levelExpNeeded;

  // levelForecast{}
  final String forecastSource;
  final int? estimatedLevelUpAt;

  // nextChecks{} + 顶层回落
  final int? nextFarmRunAt;
  final int? nextFriendRunAt;
  final bool farmQuiet;
  final bool friendQuiet;

  // 顶层统计
  final int? serverTime;
  final int uptime;
  final int sessionElapsedSeconds;
  final int sessionExpGained;
  final int sessionGoldGained;
  final int sessionCouponGained;

  /// operations{} 是动态键，值都是次数，例如 harvest: 12
  final Map<String, int> operations;

  const StatusSnapshot({
    required this.accountId,
    required this.name,
    required this.level,
    required this.exp,
    required this.gold,
    required this.coupon,
    required this.goldBean,
    required this.avatarUrl,
    required this.connected,
    required this.levelExpCurrent,
    required this.levelExpNeeded,
    required this.forecastSource,
    required this.estimatedLevelUpAt,
    required this.nextFarmRunAt,
    required this.nextFriendRunAt,
    required this.farmQuiet,
    required this.friendQuiet,
    required this.serverTime,
    required this.uptime,
    required this.sessionElapsedSeconds,
    required this.sessionExpGained,
    required this.sessionGoldGained,
    required this.sessionCouponGained,
    required this.operations,
  });

  /// 升级进度百分比，0~1
  double get levelProgress {
    if (levelExpNeeded <= 0) return 0;
    return (levelExpCurrent / levelExpNeeded).clamp(0.0, 1.0);
  }

  /// 当前可升级（服务端标记 ready）
  bool get canLevelUp => forecastSource == 'ready';

  factory StatusSnapshot.parse(String accountId, dynamic raw, {int? serverTimeHint}) {
    final data = asMap(raw);
    final status = asMap(data['status']);
    final connection = asMap(data['connection']);
    final progress = asMap(data['levelProgress']);
    final forecast = asMap(data['levelForecast']);
    final checks = asMap(data['nextChecks']);

    final farmRunAt = intOrNull(data['nextFarmRunAt']) ?? intOrNull(checks['nextFarmRunAt']);
    final friendRunAt =
        intOrNull(data['nextFriendRunAt']) ?? intOrNull(checks['nextFriendRunAt']);

    // 静默时段：friendQuiet 为主，helpQuiet / stealQuiet 任一为真也算静默
    final friendQuiet = boolOr(checks['friendQuiet'], false) ||
        boolOr(checks['helpQuiet'], false) ||
        boolOr(checks['stealQuiet'], false);

    final ops = <String, int>{};
    asMap(data['operations']).forEach((k, v) {
      // 原版显式跳过这两个非计数键
      if (k == 'upgrade' || k == 'levelUp') return;
      final n = intOrNull(v);
      if (n != null) ops[k] = n;
    });

    return StatusSnapshot(
      accountId: accountId,
      name: strOr(status['name'], '未知账号'),
      level: intOr(status['level'], 0),
      exp: intOr(status['exp'], 0),
      gold: intOr(status['gold'], 0),
      coupon: intOr(status['coupon'], 0),
      goldBean: intOr(status['goldBean'], 0),
      avatarUrl: strOr(status['avatarUrl'], ''),
      connected: boolOr(connection['connected'], false),
      levelExpCurrent: intOr(progress['current'], 0),
      levelExpNeeded: intOr(progress['needed'], 0),
      forecastSource: strOr(forecast['source'], ''),
      estimatedLevelUpAt: intOrNull(forecast['estimatedAt']),
      nextFarmRunAt: farmRunAt,
      nextFriendRunAt: friendRunAt,
      farmQuiet: boolOr(checks['farmQuiet'], false),
      friendQuiet: friendQuiet,
      serverTime: intOrNull(data['serverTime']) ?? serverTimeHint,
      uptime: intOr(data['uptime'], 0),
      sessionElapsedSeconds: intOr(data['sessionElapsedSeconds'], 0),
      sessionExpGained: intOr(data['sessionExpGained'], 0),
      sessionGoldGained: intOr(data['sessionGoldGained'], 0),
      sessionCouponGained: intOr(data['sessionCouponGained'], 0),
      operations: ops,
    );
  }

  /// Socket 的 status:update 里 status 是独立对象，包一层再解析
  factory StatusSnapshot.fromSocket(String accountId, dynamic statusObj, int? serverTime) {
    return StatusSnapshot.parse(
      accountId,
      {'status': statusObj, 'serverTime': serverTime},
      serverTimeHint: serverTime,
    );
  }
}
