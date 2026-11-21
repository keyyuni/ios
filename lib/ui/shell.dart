import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_controller.dart';
import 'pages/discover_page.dart';
import 'pages/farm_page.dart';
import 'pages/friends_page.dart';
import 'pages/me_page.dart';
import 'pages/overview_page.dart';

/// 主壳：底部 5 个标签页 + 顶部账号切换。
/// 对应安卓版 5-Tab 信息架构：总览 · 农场/牧场 · 发现 · 好友 · 我的。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  late final AppController _controller;

  static const _titles = ['总览', '农场', '发现', '好友', '我的'];

  @override
  void initState() {
    super.initState();
    _controller = context.read<AppController>();
    _controller.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChanged);
    super.dispose();
  }

  /// 把 Controller 的一次性提示转成 SnackBar
  void _onStateChanged() {
    final msg = _controller.notice;
    if (msg == null || !mounted) return;
    _controller.clearNotice();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(12),
        ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(_titles[_index]),
            const SizedBox(width: 8),
            if (controller.realtimeConnected)
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
              )
            else
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: scheme.outlineVariant, shape: BoxShape.circle),
              ),
          ],
        ),
        actions: [
          _AccountSwitcher(controller: controller),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          OverviewPage(),
          FarmPage(),
          DiscoverPage(),
          FriendsPage(),
          MePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: '总览'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: '农场'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: '发现'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: '好友'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}

/// 顶部的账号下拉切换。多账号用户的核心入口。
class _AccountSwitcher extends StatelessWidget {
  const _AccountSwitcher({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = controller.currentAccount;
    final label = current?.name ?? (controller.accountsLoading ? '加载中' : '无账号');

    return PopupMenuButton<String>(
      tooltip: '切换账号',
      onSelected: (id) => controller.selectAccount(id),
      itemBuilder: (ctx) {
        if (controller.accounts.isEmpty) {
          return [
            const PopupMenuItem(
              enabled: false,
              child: Text('服务端还没有账号', style: TextStyle(fontSize: 13)),
            ),
          ];
        }
        return controller.accounts.map((a) {
          final selected = a.id == controller.accountId;
          return PopupMenuItem<String>(
            value: a.id,
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 16,
                  color: selected ? scheme.primary : scheme.outlineVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    a.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: a.online ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(a.platformLabel, style: const TextStyle(fontSize: 10)),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz, size: 15, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
