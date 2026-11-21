import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../state/app_controller.dart';

/// 我的页：服务器信息、账号列表运维、退出授权。
class MePage extends StatelessWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primaryContainer,
                child: Icon(Icons.person, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.username.isEmpty ? '已授权用户' : c.username,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Gap.h4,
                    Text(
                      c.serverUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: scheme.outline),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  c.authMode == 'token' ? 'Token' : '密码',
                  style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        Gap.h24,

        Row(
          children: [
            Text('账号列表', style: Theme.of(context).textTheme.titleSmall),
            Gap.w8,
            if (c.accountsLoading)
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
            const Spacer(),
            TextButton.icon(
              onPressed: c.refreshAccounts,
              icon: const Icon(Icons.refresh, size: 15),
              label: const Text('刷新', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        if (c.accounts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('服务端暂无账号', style: TextStyle(fontSize: 12, color: scheme.outline)),
            ),
          )
        else
          ...c.accounts.map((a) => _AccountRow(account: a, controller: c)),

        Gap.h24,
        Text('关于', style: Theme.of(context).textTheme.titleSmall),
        Gap.h8,
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv(context, '应用', '农场助手 iOS 版 0.1.0'),
              _kv(context, '实时通道', c.realtimeConnected ? '已连接' : '未连接'),
              _kv(context, '当前账号', c.currentAccount?.name ?? '-'),
            ],
          ),
        ),
        Gap.h24,
        OutlinedButton.icon(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('退出当前授权？'),
                content: const Text('退出后需要重新输入服务器地址与凭证。本机不会删除服务端任何数据。'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('退出')),
                ],
              ),
            );
            if (ok == true) await c.logout();
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            foregroundColor: scheme.error,
            side: BorderSide(color: scheme.error.withValues(alpha: 0.4)),
          ),
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('退出登录'),
        ),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(k, style: TextStyle(fontSize: 12, color: scheme.outline)),
          const Spacer(),
          Flexible(
            child: Text(
              v,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.controller});

  final dynamic account;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = account.name as String;
    final platform = account.platformLabel as String;
    final online = account.online as bool;
    final isCurrent = account.id == controller.accountId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: isCurrent ? Border.all(color: scheme.primary.withValues(alpha: 0.4)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: online ? const Color(0xFF2E7D32) : scheme.outlineVariant,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(platform, style: TextStyle(fontSize: 10, color: scheme.outline)),
                    if (isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('当前', style: TextStyle(fontSize: 9, color: scheme.onPrimaryContainer)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(online ? '运行中' : '已停止', style: TextStyle(fontSize: 11, color: scheme.outline)),
              ],
            ),
          ),
          IconButton(
            tooltip: '切换到此账号',
            onPressed: isCurrent ? null : () => controller.selectAccount(account.id as String),
            icon: const Icon(Icons.login, size: 17),
          ),
          IconButton(
            tooltip: online ? '停止' : '启动',
            onPressed: () async {
              final msg = online
                  ? await controller.stopAccount(account.id as String)
                  : await controller.startAccount(account.id as String);
              if (msg != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              }
            },
            icon: Icon(online ? Icons.stop_circle_outlined : Icons.play_circle_outline, size: 18),
          ),
        ],
      ),
    );
  }
}
