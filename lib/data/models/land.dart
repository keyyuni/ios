import '../../core/json.dart';

/// 地块数据结构，对应安卓版 land 解析。
class Land {
  final int id;
  final int level;
  final bool unlocked;
  /// empty / growing / mature / dead ...，服务端原样字符串
  final String status;
  final String plantName;
  final String phaseName;
  final String seedImage;
  final int matureInSec;
  final int totalGrowTime;
  final int currentSeason;
  final int totalSeason;
  final bool needWater;
  final bool needWeed;
  final bool needBug;
  final bool needInteractionCleanup;
  final bool couldUnlock;
  final bool couldUpgrade;
  final int plantSize;
  final int? leftInorcFertTimes;
  final bool occupiedByMaster;
  final int masterLandId;
  final List<String> mutantEffects;
  final LandUpgradeInfo? upgradeInfo;

  const Land({
    required this.id,
    required this.level,
    required this.unlocked,
    required this.status,
    required this.plantName,
    required this.phaseName,
    required this.seedImage,
    required this.matureInSec,
    required this.totalGrowTime,
    required this.currentSeason,
    required this.totalSeason,
    required this.needWater,
    required this.needWeed,
    required this.needBug,
    required this.needInteractionCleanup,
    required this.couldUnlock,
    required this.couldUpgrade,
    required this.plantSize,
    required this.leftInorcFertTimes,
    required this.occupiedByMaster,
    required this.masterLandId,
    required this.mutantEffects,
    required this.upgradeInfo,
  });

  bool get isMature => status == 'mature' || (status == 'growing' && matureInSec <= 0);
  bool get isEmpty => status == 'empty';
  bool get isDead => status == 'dead';

  /// 需要护理（缺水/杂草/虫害/社交残留），服务端统一用 clear 操作处理
  bool get needsCare => needWater || needWeed || needBug || needInteractionCleanup;

  /// 单块地的一键护理提示文案
  String get careLabel {
    final parts = <String>[];
    if (needWater) parts.add('缺水');
    if (needWeed) parts.add('杂草');
    if (needBug) parts.add('虫害');
    if (needInteractionCleanup) parts.add('残留');
    return parts.join('·');
  }

  factory Land.parse(dynamic raw) {
    final m = asMap(raw);
    final effects = asList(m['mutantEffects'])
        .map((e) {
          final em = asMap(e);
          return strOrNull(em['name']) ?? strOrNull(em['effect_name']) ?? '';
        })
        .where((e) => e.isNotEmpty)
        .toList();

    return Land(
      id: intOr(m['id'], 0),
      level: intOr(m['level'], 1),
      unlocked: boolOr(m['unlocked'], true),
      status: strOr(m['status'], 'empty'),
      plantName: strOr(m['plantName'], ''),
      phaseName: strOr(m['phaseName'], ''),
      seedImage: strOr(m['seedImage'], ''),
      matureInSec: intOr(m['matureInSec'], 0),
      totalGrowTime: intOr(m['totalGrowTime'], 0),
      currentSeason: intOr(m['currentSeason'], 1),
      totalSeason: intOr(m['totalSeason'], 1),
      needWater: boolOr(m['needWater'], false),
      needWeed: boolOr(m['needWeed'], false),
      needBug: boolOr(m['needBug'], false),
      needInteractionCleanup: boolOr(m['needInteractionCleanup'], false),
      couldUnlock: boolOr(m['couldUnlock'], false),
      couldUpgrade: boolOr(m['couldUpgrade'], false),
      plantSize: intOr(m['plantSize'], 1),
      leftInorcFertTimes: intOrNull(m['leftInorcFertTimes']),
      occupiedByMaster: boolOr(m['occupiedByMaster'], false),
      masterLandId: intOr(m['masterLandId'], 0),
      mutantEffects: effects,
      upgradeInfo: m['landInfo'] == null ? null : LandUpgradeInfo.parse(m['landInfo']),
    );
  }
}

/// 土地升级信息
class LandUpgradeInfo {
  final String mode;
  final int currentLevel;
  final String currentName;
  final double currentYieldBonus;
  final int nextLevel;
  final String nextName;
  final double nextYieldBonus;
  final bool serverAllowed;
  final int? needLevel;
  final bool prerequisiteMet;
  final int prerequisiteLandId;
  final String precedingName;
  final int precedingRequired;
  final int? precedingOwned;
  final List<LandUpgradeCost> costs;

  const LandUpgradeInfo({
    required this.mode,
    required this.currentLevel,
    required this.currentName,
    required this.currentYieldBonus,
    required this.nextLevel,
    required this.nextName,
    required this.nextYieldBonus,
    required this.serverAllowed,
    required this.needLevel,
    required this.prerequisiteMet,
    required this.prerequisiteLandId,
    required this.precedingName,
    required this.precedingRequired,
    required this.precedingOwned,
    required this.costs,
  });

  factory LandUpgradeInfo.parse(dynamic raw) {
    final m = asMap(raw);
    final cur = asMap(m['current']);
    final next = asMap(m['next']);
    final pre = asMap(m['prerequisite']);
    final preceding = asMap(m['precedingLands']);
    return LandUpgradeInfo(
      mode: strOr(m['mode'], ''),
      currentLevel: intOr(cur['level'], 0),
      currentName: strOr(cur['name'], ''),
      currentYieldBonus: doubleOr(cur['yieldBonus'], 0),
      nextLevel: intOr(next['level'], 0),
      nextName: strOr(next['name'], ''),
      nextYieldBonus: doubleOr(next['yieldBonus'], 0),
      serverAllowed: boolOr(m['serverAllowed'], false),
      needLevel: intOrNull(m['needLevel']),
      prerequisiteMet: boolOr(pre['met'], true),
      prerequisiteLandId: intOr(pre['landId'], 0),
      precedingName: strOr(preceding['name'], ''),
      precedingRequired: intOr(preceding['required'], 0),
      precedingOwned: intOrNull(preceding['owned']),
      costs: asList(m['costs'])
          .map((e) => LandUpgradeCost.parse(e))
          .where((e) => e.count.isNotEmpty)
          .toList(),
    );
  }
}

class LandUpgradeCost {
  final String id;
  final String name;
  final String image;
  /// 原版是字符串（可能带单位），保留原文
  final String count;

  const LandUpgradeCost({
    required this.id,
    required this.name,
    required this.image,
    required this.count,
  });

  factory LandUpgradeCost.parse(dynamic raw) {
    final m = asMap(raw);
    return LandUpgradeCost(
      id: strOr(m['id'], ''),
      name: strOr(m['name'], ''),
      image: strOr(m['image'], ''),
      count: strOr(m['count'], '0'),
    );
  }
}

/// /api/lands 的整体响应
class LandsPayload {
  final List<Land> lands;
  final int harvestable;
  final int growing;
  final int empty;
  final int dead;
  final int needWater;
  final int needWeed;
  final int needBug;
  final List<String> cleanableItems;

  const LandsPayload({
    required this.lands,
    required this.harvestable,
    required this.growing,
    required this.empty,
    required this.dead,
    required this.needWater,
    required this.needWeed,
    required this.needBug,
    required this.cleanableItems,
  });

  /// 服务端 summary 缺失时，用本地地块自行汇总，保证界面永远有数
  factory LandsPayload.parse(dynamic raw) {
    final m = asMap(raw);
    final lands = asList(m['lands']).map((e) => Land.parse(e)).toList();
    final summary = asMap(m['summary']);

    final cleanables = asList(m['socialEvents'])
        .where((e) => boolOr(asMap(e)['cleanable'], false))
        .map((e) {
          final em = asMap(e);
          return strOrNull(em['itemName']) ?? strOrNull(em['name']) ?? '';
        })
        .where((e) => e.isNotEmpty)
        .toList();

    int countIf(bool Function(Land) test) => lands.where(test).length;

    return LandsPayload(
      lands: lands,
      harvestable: intOrNull(summary['harvestable']) ?? countIf((l) => l.isMature),
      growing: intOrNull(summary['growing']) ?? countIf((l) => !l.isMature && !l.isEmpty),
      empty: intOrNull(summary['empty']) ?? countIf((l) => l.isEmpty),
      dead: intOrNull(summary['dead']) ?? countIf((l) => l.isDead),
      needWater: intOrNull(summary['needWater']) ?? countIf((l) => l.needWater),
      needWeed: intOrNull(summary['needWeed']) ?? countIf((l) => l.needWeed),
      needBug: intOrNull(summary['needBug']) ?? countIf((l) => l.needBug),
      cleanableItems: cleanables,
    );
  }
}
