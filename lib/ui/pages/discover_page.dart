import 'package:flutter/material.dart';

/// 发现中心（活动 · 商城 · 节令日历）。
/// 安卓版对应 DiscoverScreen → ActivityCenter / Mall / SolarCalendar 三个子模块。
/// 当前版本先落地入口骨架，具体活动界面按批次接入对应接口。
class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = <(IconData, String, String)>[
      (Icons.celebration_outlined, '活动中心', '限时活动、常驻活动与往期活动目录'),
      (Icons.storefront_outlined, '商城', '游戏商城、道具店、神秘商人、SVIP'),
      (Icons.calendar_month_outlined, '节令日历', '节令卡片、当季进度与答题领奖'),
      (Icons.auto_awesome_outlined, '星际游记', '星旅进度、星宿点亮与星沙兑换'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: scheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '发现中心接口已接通，界面正在按模块接入。先阶段的日常操作请在「总览」和「农场」完成。',
                  style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(e.$1, size: 20, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(e.$3, style: TextStyle(fontSize: 11.5, color: scheme.outline)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('待接入', style: TextStyle(fontSize: 9.5, color: scheme.onSurfaceVariant)),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
