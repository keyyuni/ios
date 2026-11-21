import 'package:flutter/material.dart';

/// 好友互动页（访问、偷取、照顾、黑名单）。
/// 接口已在 FarmApiClient 中就绪，界面按批次接入。
class FriendsPage extends StatelessWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 44, color: scheme.outline),
            const SizedBox(height: 16),
            const Text('好友互动', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              '好友列表、可偷可帮筛选、访问记录与黑名单正在接入。\n'
              '服务端的自动好友互动已在运行，不受本页影响。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: scheme.outline, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
