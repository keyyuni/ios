import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models/land.dart';
import '../../state/app_controller.dart';

/// 农场工作台：3 列土地宫格 + 成熟倒计时 + 一键操作。
/// 对应安卓版 FarmRanchScreen 的农场部分。
class FarmPage extends StatelessWidget {
  const FarmPage({super.key});

  Future<void> _act(BuildContext context, Future<String?> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final msg = await action();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg ?? '操作已提交'), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final payload = c.lands;

    if (!c.hasAccount) {
      return const Center(child: Text('请先在顶部选择一个账号'));
    }

    return RefreshIndicator(
      onRefresh: c.refreshLands,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SummaryBar(payload: payload, loading: c.landsLoading),
          Gap.h12,
          _ActionBar(
            onHarvest: () => _act(context, () => c.farmOp('harvest')),
            onClear: () => _act(context, () => c.farmOp('clear')),
            onPlant: () => _act(context, () => c.farmOp('plant')),
            onFertilizeNormal: () => _act(context, () => c.fertilizeAll('normal')),
            onFertilizeOrganic: () => _act(context, () => c.fertilizeAll('organic')),
          ),
          Gap.h16,
          if (payload == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (payload.lands.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Text('还没有土地数据，下拉刷新试试',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline)),
              ),
            )
          else
            LayoutBuilder(builder: (ctx, box) {
              const gap = 10.0;
              final w = (box.maxWidth - gap * 2) / 3;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: payload.lands
                    .map((land) => SizedBox(
                          width: w,
                          child: LandTile(
                            land: land,
                            onTap: () => _openLandSheet(context, land),
                          ),
                        ))
                    .toList(),
              );
            }),
        ],
      ),
    );
  }

  void _openLandSheet(BuildContext context, Land land) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => _LandSheet(land: land),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.payload, required this.loading});
  final LandsPayload? payload;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = payload;
    final chips = <(String, String, Color)>[
      ('可收', '${p?.harvestable ?? '-'}', StatusColors.mature(context)),
      ('生长', '${p?.growing ?? '-'}', StatusColors.growing(context)),
      ('空地', '${p?.empty ?? '-'}', scheme.outline),
      ('枯死', '${p?.dead ?? '-'}', scheme.error),
      ('缺水', '${p?.needWater ?? '-'}', StatusColors.warn(context)),
      ('杂草', '${p?.needWeed ?? '-'}', StatusColors.warn(context)),
      ('虫害', '${p?.needBug ?? '-'}', StatusColors.warn(context)),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              children: chips
                  .map((c) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(color: c.$3, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          Text(c.$1, style: TextStyle(fontSize: 11, color: scheme.outline)),
                          const SizedBox(width: 2),
                          Text(c.$2,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ],
                      ))
                  .toList(),
            ),
          ),
          if (loading)
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.onHarvest,
    required this.onClear,
    required this.onPlant,
    required this.onFertilizeNormal,
    required this.onFertilizeOrganic,
  });

  final VoidCallback onHarvest;
  final VoidCallback onClear;
  final VoidCallback onPlant;
  final VoidCallback onFertilizeNormal;
  final VoidCallback onFertilizeOrganic;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = <(IconData, String, VoidCallback)>[
      (Icons.shopping_basket_outlined, '收获', onHarvest),
      (Icons.cleaning_services_outlined, '护理', onClear),
      (Icons.spa_outlined, '种植', onPlant),
      (Icons.water_drop_outlined, '普通肥', onFertilizeNormal),
      (Icons.eco_outlined, '有机肥', onFertilizeOrganic),
    ];

    return Row(
      children: items.map((it) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: it == items.last ? 0 : 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: it.$3,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(it.$1, size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 4),
                    Text(it.$2, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 单块土地卡片。自带 1 秒倒计时，避免整页每秒重建。
class LandTile extends StatefulWidget {
  const LandTile({super.key, required this.land, required this.onTap});

  final Land land;
  final VoidCallback onTap;

  @override
  State<LandTile> createState() => _LandTileState();
}

class _LandTileState extends State<LandTile> {
  late int _seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _seconds = widget.land.matureInSec;
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant LandTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.land.matureInSec != widget.land.matureInSec ||
        oldWidget.land.id != widget.land.id) {
      _seconds = widget.land.matureInSec;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _seconds <= 0) {
        t.cancel();
        return;
      }
      setState(() => _seconds -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final land = widget.land;
    final mature = land.isMature || _seconds <= 0;

    Color accent;
    if (!land.unlocked) {
      accent = scheme.outlineVariant;
    } else if (land.isDead) {
      accent = scheme.error;
    } else if (land.isEmpty) {
      accent = scheme.outline;
    } else if (mature) {
      accent = StatusColors.mature(context);
    } else {
      accent = StatusColors.growing(context);
    }

    final title = !land.unlocked
        ? '未解锁'
        : land.isEmpty
            ? '空地'
            : land.isDead
                ? (land.plantName.isEmpty ? '枯萎' : land.plantName)
                : (land.plantName.isEmpty ? land.phaseName : land.plantName);

    final subtitle = !land.unlocked
        ? (land.couldUnlock ? '可解锁' : '需前置')
        : land.isEmpty
            ? null
            : land.isDead
                ? '枯死'
                : mature
                    ? '可收获'
                    : countdownText(_seconds);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: widget.onTap,
      child: Container(
        height: 104,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.075),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.35), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${land.id}',
                    style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                if (land.leftInorcFertTimes != null && land.leftInorcFertTimes! > 0)
                  Icon(Icons.water_drop, size: 11, color: accent.withValues(alpha: 0.8)),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: accent),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 10.5, color: accent.withValues(alpha: 0.85))),
            ],
            const Spacer(),
            Row(
              children: [
                if (land.needWater) _dot(context, Icons.water_drop_outlined, const Color(0xFF3B82F6)),
                if (land.needWeed) _dot(context, Icons.grass_outlined, const Color(0xFF16A34A)),
                if (land.needBug) _dot(context, Icons.bug_report_outlined, const Color(0xFFD97706)),
                if (land.needInteractionCleanup) _dot(context, Icons.auto_delete_outlined, const Color(0xFF9333EA)),
                const Spacer(),
                if (land.currentSeason > 1 && land.totalSeason > 1)
                  Text('${land.currentSeason}/${land.totalSeason}',
                      style: TextStyle(fontSize: 9.5, color: accent.withValues(alpha: 0.8))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(BuildContext context, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: Icon(icon, size: 12, color: color),
    );
  }
}

/// 单块地详情弹窗
class _LandSheet extends StatelessWidget {
  const _LandSheet({required this.land});
  final Land land;

  @override
  Widget build(BuildContext context) {
    final c = context.read<AppController>();
    final scheme = Theme.of(context).colorScheme;

    // 弹窗关闭后再提示，所以先把 messenger 取出来，避免 pop 之后 context 失效
    Future<void> run(Future<String?> Function() fn) async {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      final msg = await fn();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg ?? '操作已提交')));
    }

    final info = land.upgradeInfo;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('地块 ${land.id}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Gap.w8,
                if (land.plantName.isNotEmpty)
                  Text(land.plantName, style: TextStyle(fontSize: 13, color: scheme.outline)),
              ],
            ),
            Gap.h8,
            Text(
              [
                '等级 ${land.level}',
                if (land.phaseName.isNotEmpty) land.phaseName,
                if (land.careLabel.isNotEmpty) '需${land.careLabel}',
                if (land.mutantEffects.isNotEmpty) land.mutantEffects.join('·'),
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
            Gap.h16,
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (land.needsCare)
                  _sheetBtn(context, Icons.cleaning_services_outlined, '立即护理',
                      () => run(() => c.farmOp('clear', landId: land.id))),
                if (land.isMature)
                  _sheetBtn(context, Icons.shopping_basket_outlined, '收获（全部成熟）',
                      () => run(() => c.farmOp('harvest'))),
                if (land.isEmpty || land.isDead)
                  _sheetBtn(context, Icons.spa_outlined, '种植（全部空地）',
                      () => run(() => c.farmOp('plant'))),
                _sheetBtn(context, Icons.water_drop_outlined, '施普通肥',
                    () => run(() => c.fertilizeLand(land.id, 'normal'))),
                _sheetBtn(context, Icons.eco_outlined, '施有机肥',
                    () => run(() => c.fertilizeLand(land.id, 'organic'))),
                if (land.couldUnlock || land.couldUpgrade)
                  _sheetBtn(context, Icons.upgrade_outlined, '批量解锁与升级', () async {
                    // 先确认再关闭弹窗，顺序反了会拿不到有效 context
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('确认升级地块？'),
                        content: const Text('升级会消耗资源，且不可撤销。确认后将对该地块执行升级操作。'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认升级')),
                        ],
                      ),
                    );
                    if (ok != true || !context.mounted) return;
                    await run(() => c.farmOp('upgrade'));
                  }),
              ],
            ),
            if (info != null && info.nextLevel > 0) ...[
              Gap.h16,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('升级预览', style: TextStyle(fontSize: 12, color: scheme.outline)),
                    Gap.h8,
                    Text(
                      'Lv.${info.currentLevel} ${info.currentName} → Lv.${info.nextLevel} ${info.nextName}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    if (info.costs.isNotEmpty) ...[
                      Gap.h8,
                      Text(
                        '消耗：${info.costs.map((e) => '${e.name}×${e.count}').join('、')}',
                        style: TextStyle(fontSize: 11.5, color: scheme.outline),
                      ),
                    ],
                    if (!info.serverAllowed) ...[
                      Gap.h4,
                      Text('服务端当前不允许升级',
                          style: TextStyle(fontSize: 11.5, color: StatusColors.warn(context))),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sheetBtn(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12.5)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    );
  }
}
