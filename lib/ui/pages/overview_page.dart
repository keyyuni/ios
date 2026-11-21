import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../state/app_controller.dart';

/// 总览页：账号状态、资产、今日统计、运行日志。
/// 对应安卓版 OverviewScreen。
class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();

    if (!c.hasAccount) {
      return _EmptyAccounts(controller: c);
    }

    return RefreshIndicator(
      onRefresh: c.refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _StatusCard(controller: c),
          Gap.h12,
          _AssetRow(controller: c),
          Gap.h12,
          _TodayStats(controller: c),
          Gap.h12,
          _QuickActions(controller: c),
          Gap.h16,
          _LogSection(controller: c),
        ],
      ),
    );
  }
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined, size: 44, color: scheme.outline),
            Gap.h16,
            const Text('服务端还没有可管理的账号', style: TextStyle(fontWeight: FontWeight.w500)),
            Gap.h8,
            Text(
              '请先在网页管理面板里添加账号并完成扫码登录，再回到本应用下拉刷新。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.outline, height: 1.5),
            ),
            Gap.h16,
            OutlinedButton.icon(
              onPressed: controller.refreshAccounts,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重新获取账号'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = controller.status;
    final online = s?.connected ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.agriculture_outlined, size: 22, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s?.name ?? controller.currentAccount?.name ?? '账号',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Gap.h4,
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: online ? const Color(0xFF2E7D32) : scheme.outlineVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          online ? '在线运行中' : '未连接',
                          style: TextStyle(fontSize: 12, color: scheme.outline),
                        ),
                        if (s != null) ...[
                          const SizedBox(width: 10),
                          Text('Lv.${s.level}', style: TextStyle(fontSize: 12, color: scheme.outline)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (controller.statusLoading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(
                  tooltip: '刷新',
                  onPressed: controller.refreshStatus,
                  icon: const Icon(Icons.refresh, size: 20),
                ),
            ],
          ),
          if (s != null && s.levelExpNeeded > 0) ...[
            Gap.h16,
            Row(
              children: [
                Text('升级进度', style: TextStyle(fontSize: 12, color: scheme.outline)),
                const Spacer(),
                Text(
                  '${groupedNum(s.levelExpCurrent)} / ${groupedNum(s.levelExpNeeded)}',
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
              ],
            ),
            Gap.h8,
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: s.levelProgress,
                minHeight: 7,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            if (s.canLevelUp) ...[
              Gap.h8,
              Text('经验已满，可立即升级', style: TextStyle(fontSize: 12, color: StatusColors.warn(context))),
            ],
          ],
          if (s != null) ...[
            Gap.h12,
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _miniInfo(context, '下次农场', clockText(s.nextFarmRunAt)),
                _miniInfo(context, '下次好友', clockText(s.nextFriendRunAt)),
                _miniInfo(context, '运行时长', countdownText(s.uptime)),
                if (s.farmQuiet) _miniInfo(context, '农场', '静默中'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniInfo(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: TextStyle(fontSize: 11, color: scheme.outline)),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.status;
    return Row(
      children: [
        _asset(context, '金币', s == null ? '--' : compactNum(s.gold), Icons.monetization_on_outlined),
        Gap.w8,
        _asset(context, '点券', s == null ? '--' : compactNum(s.coupon), Icons.confirmation_number_outlined),
        Gap.w8,
        _asset(context, '金豆', s == null ? '--' : compactNum(s.goldBean), Icons.savings_outlined),
        Gap.w8,
        _asset(context, '钻石', compactNum(controller.diamond), Icons.diamond_outlined),
      ],
    );
  }

  Widget _asset(BuildContext context, String label, String value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 17, color: scheme.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: scheme.outline)),
          ],
        ),
      ),
    );
  }
}

class _TodayStats extends StatelessWidget {
  const _TodayStats({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.status;
    if (s == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('本次会话', style: TextStyle(fontSize: 12, color: scheme.outline)),
          Gap.h12,
          Row(
            children: [
              _stat(context, '+${compactNum(s.sessionExpGained)}', '经验'),
              _stat(context, '+${compactNum(s.sessionGoldGained)}', '金币'),
              _stat(context, '+${compactNum(s.sessionCouponGained)}', '点券'),
              _stat(context, countdownText(s.sessionElapsedSeconds), '时长'),
            ],
          ),
          if (s.operations.isNotEmpty) ...[
            Gap.h12,
            Divider(color: scheme.outlineVariant.withValues(alpha: 0.4), height: 1),
            Gap.h12,
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: s.operations.entries
                  .where((e) => e.value > 0)
                  .take(12)
                  .map((e) => Text(
                        '${_opName(e.key)} ${e.value}',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: scheme.outline)),
        ],
      ),
    );
  }

  String _opName(String key) {
    const map = {
      'harvest': '收获',
      'plant': '种植',
      'water': '浇水',
      'weed': '除草',
      'bug': '除虫',
      'clear': '清理',
      'fertilize': '施肥',
      'steal': '偷取',
      'help': '帮助',
      'friend': '好友',
      'visit': '访问',
      'feed': '喂养',
      'task': '任务',
    };
    return map[key] ?? key;
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.controller});
  final AppController controller;

  Future<void> _run(BuildContext context, Future<String?> Function() action) async {
    final ctx = context;
    final msg = await action();
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg ?? '操作已提交'), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _pill(context, Icons.shopping_basket_outlined, '一键收获', () => _run(context, () => controller.farmOp('harvest'))),
        _pill(context, Icons.cleaning_services_outlined, '一键清理', () => _run(context, () => controller.farmOp('clear'))),
        _pill(context, Icons.spa_outlined, '一键种植', () => _run(context, () => controller.farmOp('plant'))),
        _pill(context, Icons.bolt_outlined, '全自动', () => _run(context, () => controller.farmOp('all'))),
      ],
    );
  }

  Widget _pill(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: scheme.onPrimaryContainer),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, color: scheme.onPrimaryContainer)),
          ],
        ),
      ),
    );
  }
}

class _LogSection extends StatelessWidget {
  const _LogSection({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final logs = controller.logs.reversed.take(60).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('运行日志', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton(
              onPressed: () async {
                final msg = await controller.clearLogs();
                if (msg != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                }
              },
              child: const Text('清空', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        Container(
          constraints: const BoxConstraints(maxHeight: 420),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light
                ? const Color(0xFFF7F7F5)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: logs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('暂无日志', style: TextStyle(fontSize: 12, color: scheme.outline)),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (ctx, i) {
                    final e = logs[i];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clockText(e.timeMs),
                          style: TextStyle(fontSize: 10, color: scheme.outline),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.message,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.4,
                              color: e.isWarn ? const Color(0xFFB3261E) : scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}
