import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/api_client.dart';
import '../../state/app_controller.dart';

/// 首次连接页：填服务器地址 → 两种授权方式（密码 / Token）。
/// 对应安卓版 ServerSetupScreen。
class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _urlCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();

  bool _useToken = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  String? _okText;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _error = null;
      _okText = null;
    });
    final controller = context.read<AppController>();
    try {
      final msg = await controller.testServer(_urlCtrl.text);
      setState(() => _okText = msg);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '连接失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _okText = null;
    });
    final controller = context.read<AppController>();
    final err = _useToken
        ? await controller.connectWithToken(_urlCtrl.text, _tokenCtrl.text)
        : await controller.connectWithPassword(_urlCtrl.text, _userCtrl.text, _passCtrl.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      if (err == null) _okText = '登录成功，正在同步数据…';
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.agriculture_outlined, size: 34, color: scheme.onPrimaryContainer),
            ),
            Gap.h16,
            Text('连接你的农场服务', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
            Gap.h8,
            Text(
              '填入自建 qq-farm-bot 服务的地址，支持局域网 IP、域名和 HTTPS 反向代理。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline, height: 1.5),
            ),
            Gap.h24,

            TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                hintText: 'https://farm.example.com',
                prefixIcon: Icon(Icons.dns_outlined),
              ),
            ),
            Gap.h12,
            OutlinedButton.icon(
              onPressed: _busy ? null : _test,
              icon: const Icon(Icons.wifi_tethering, size: 18),
              label: const Text('测试连接'),
            ),

            Gap.h24,
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('账号密码'), icon: Icon(Icons.password, size: 16)),
                ButtonSegment(value: true, label: Text('会话 Token'), icon: Icon(Icons.key_outlined, size: 16)),
              ],
              selected: {_useToken},
              onSelectionChanged: (v) => setState(() => _useToken = v.first),
            ),
            Gap.h16,

            if (!_useToken) ...[
              TextField(
                controller: _userCtrl,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: '管理员用户名',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              Gap.h12,
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: '密码',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ] else
              TextField(
                controller: _tokenCtrl,
                autocorrect: false,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'x-admin-token',
                  hintText: '从网页管理面板登录后获取',
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
              ),

            if (_error != null) ...[
              Gap.h16,
              _Banner(text: _error!, isError: true),
            ],
            if (_okText != null) ...[
              Gap.h16,
              _Banner(text: _okText!, isError: false),
            ],

            Gap.h24,
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_useToken ? '用 Token 授权' : '登录'),
            ),
            Gap.h16,
            Text(
              '提示：Token 方式适合服务端重启后不想重登的场景；'
              '密码方式会自动获取新的会话凭证，重启后重新登录即可。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isError ? scheme.errorContainer : scheme.primaryContainer;
    final fg = isError ? scheme.onErrorContainer : scheme.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: fg, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
