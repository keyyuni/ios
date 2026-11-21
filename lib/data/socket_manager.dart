import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/json.dart';
import 'models/account.dart';
import 'models/log_entry.dart';
import 'models/status_snapshot.dart';

/// Socket.IO 实时通道。
///
/// 对齐安卓版 RealtimeSocketManager：
/// - 连接地址取服务器 origin，path 为「基础路径 + /socket.io」
/// - 只走 websocket 传输，断线自动重连（2s 起，最长 10s）
/// - 握手时通过 auth 传 token 与 accountId
/// - 连上后必须 emit 'subscribe' 才会收到该账号的推送
class RealtimeSocket {
  io.Socket? _socket;
  String _activeUrl = '';
  String _activeToken = '';
  String _accountId = '';

  bool connected = false;

  void Function(bool connected)? onConnectionChanged;
  void Function(String accountId, StatusSnapshot snapshot)? onStatus;
  void Function(RunLogEntry entry)? onNewLog;
  void Function(String accountId, List<RunLogEntry> logs)? onLogSnapshot;
  void Function(AccountLogEvent event)? onAccountLog;

  /// 把 https://host/base 拆成 origin + socket path
  static ({String origin, String path})? _resolve(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.host.isEmpty) return null;
    final origin = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    var basePath = uri.path;
    while (basePath.endsWith('/')) {
      basePath = basePath.substring(0, basePath.length - 1);
    }
    return (origin: origin, path: '$basePath/socket.io');
  }

  void connect({required String serverUrl, required String token, required String accountId}) {
    final cleanAccount = accountId.trim();
    _accountId = cleanAccount;
    if (serverUrl.isEmpty || token.isEmpty) {
      disconnect();
      return;
    }

    // 同样的地址和 token 就复用连接，只切换订阅账号
    if (_socket != null && _activeUrl == serverUrl && _activeToken == token) {
      if (_socket!.connected) {
        _emitSubscribe(cleanAccount);
      } else {
        _socket!.connect();
      }
      return;
    }

    disconnect();
    _activeUrl = serverUrl;
    _activeToken = token;

    final resolved = _resolve(serverUrl);
    if (resolved == null) return;

    final socket = io.io(
      resolved.origin,
      io.OptionBuilder()
          .setPath(resolved.path)
          .setTransports(['websocket'])
          .enableForceNew()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(10000)
          .setAuth({'token': token, 'accountId': cleanAccount.isEmpty ? 'all' : cleanAccount})
          .build(),
    );

    socket.onConnect((_) {
      connected = true;
      onConnectionChanged?.call(true);
      _emitSubscribe(_accountId);
    });

    socket.onDisconnect((_) {
      connected = false;
      onConnectionChanged?.call(false);
    });

    socket.onConnectError((_) {
      connected = false;
      onConnectionChanged?.call(false);
    });

    socket.on('status:update', (data) {
      final m = asMap(data);
      final accId = strOr(m['accountId'], '');
      if (accId.isEmpty) return;
      final statusObj = m['status'];
      if (statusObj == null) return;
      final serverTime = intOrNull(m['serverTime']);
      onStatus?.call(accId, StatusSnapshot.fromSocket(accId, statusObj, serverTime));
    });

    socket.on('log:new', (data) {
      onNewLog?.call(RunLogEntry.parse(data));
    });

    socket.on('logs:snapshot', (data) {
      final m = asMap(data);
      final accId = strOr(m['accountId'], '');
      final logs = asList(m['logs']).map((e) => RunLogEntry.parse(e)).toList();
      onLogSnapshot?.call(accId, logs);
    });

    socket.on('account-log:new', (data) {
      onAccountLog?.call(AccountLogEvent.parse(data));
    });

    _socket = socket;
    socket.connect();
  }

  void _emitSubscribe(String accountId) {
    final s = _socket;
    if (s == null) return;
    s.emit('subscribe', {'accountId': accountId.isEmpty ? 'all' : accountId});
  }

  void subscribeAccount(String accountId) {
    _accountId = accountId.trim();
    if (_socket?.connected == true) _emitSubscribe(_accountId);
  }

  void disconnect() {
    final s = _socket;
    _socket = null;
    _activeUrl = '';
    _activeToken = '';
    connected = false;
    if (s != null) {
      try {
        s.offAny();
        s.disconnect();
        s.dispose();
      } catch (_) {
        // 释放失败不影响业务流程
      }
    }
  }
}
