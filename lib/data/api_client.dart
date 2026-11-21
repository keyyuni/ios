import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/json.dart';
import 'models/account.dart';
import 'models/bag.dart';
import 'models/land.dart';
import 'models/log_entry.dart';
import 'models/status_snapshot.dart';

/// 接口异常。message 直接可以弹给用户看。
class ApiException implements Exception {
  final String message;
  final int? httpCode;

  const ApiException(this.message, {this.httpCode});

  @override
  String toString() => message;
}

/// 农场服务 HTTP 客户端。
///
/// 整体对齐安卓版 FarmApiClient：
/// - 统一附带 x-admin-token / x-account-id 两个头
/// - 分三档超时（普通 25s / 长轮询 35s / 牧场 45s），因为上游某些接口是长轮询
/// - /api/settings/save 返回 202 视为"部分成功"，不能当错误
class FarmApiClient {
  FarmApiClient() {
    _normal = _buildDio(const Duration(seconds: 25));
    _longPoll = _buildDio(const Duration(seconds: 35));
    _ranch = _buildDio(const Duration(seconds: 45));
  }

  late final Dio _normal;
  late final Dio _longPoll;
  late final Dio _ranch;

  String _baseUrl = '';
  String _token = '';
  String _accountId = '';

  /// 会话失效回调，用于自动踢回登录页
  void Function()? onUnauthorized;

  String get baseUrl => _baseUrl;

  Dio _buildDio(Duration receiveTimeout) {
    return Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: receiveTimeout,
      sendTimeout: const Duration(seconds: 12),
      responseType: ResponseType.plain,
      validateStatus: (_) => true,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    ));
  }

  /// 规范化服务器地址：补协议、去尾部斜杠。返回 null 表示地址不合法。
  static String? normalizeBaseUrl(String? input) {
    var s = (input ?? '').trim();
    if (s.isEmpty) return null;
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'https://$s';
    }
    final uri = Uri.tryParse(s);
    if (uri == null || uri.host.isEmpty) return null;
    var out = s;
    while (out.endsWith('/')) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }

  void setSession({required String serverUrl, required String token, required String accountId}) {
    _baseUrl = serverUrl;
    _token = token;
    _accountId = accountId;
  }

  void clearSession() {
    _baseUrl = '';
    _token = '';
    _accountId = '';
  }

  void setAccountId(String id) => _accountId = id;

  Map<String, String> _headers({bool withAccount = true}) {
    final h = <String, String>{};
    if (_token.isNotEmpty) h['x-admin-token'] = _token;
    if (withAccount && _accountId.isNotEmpty) h['x-account-id'] = _accountId;
    return h;
  }

  /// 统一请求出口。返回解析后的 JSON（Map / List / null）。
  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool longPoll = false,
    bool ranch = false,
    bool useAccountHeader = true,
    String? overrideUrl,
    String? overrideToken,
  }) async {
    final base = overrideUrl ?? _baseUrl;
    if (base.isEmpty) throw const ApiException('请先配置服务器地址');

    final headers = (overrideUrl != null || overrideToken != null)
        ? <String, String>{
            if ((overrideToken ?? '').isNotEmpty) 'x-admin-token': overrideToken!,
          }
        : _headers(withAccount: useAccountHeader);

    final dio = ranch ? _ranch : (longPoll ? _longPoll : _normal);

    Response<String> resp;
    try {
      resp = await dio.request<String>(
        '$base$path',
        data: body ?? (method == 'GET' ? null : <String, dynamic>{}),
        queryParameters: query,
        options: Options(method: method, headers: headers),
      );
    } on DioException catch (e) {
      throw ApiException(_networkMessage(e));
    }

    final code = resp.statusCode ?? 0;
    final text = resp.data ?? '';
    dynamic decoded;
    if (text.isNotEmpty) {
      try {
        decoded = _decode(text);
      } catch (_) {
        decoded = text;
      }
    }

    if (code >= 200 && code < 300) {
      // 202 = 部分成功，照样把内容交给调用方
      return decoded;
    }
    if (code == 401 || code == 403) {
      onUnauthorized?.call();
    }
    throw ApiException(_errorMessage(decoded, code), httpCode: code);
  }

  dynamic _decode(String text) {
    final t = text.trimLeft();
    if (t.startsWith('{') || t.startsWith('[')) {
      return _jsonDecode(text);
    }
    return text;
  }

  dynamic _jsonDecode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      // 服务端个别接口返回非标准 JSON（如纯文本 "ok"），交给调用方当字符串处理
      return text;
    }
  }

  String _networkMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接服务器超时，请检查地址和网络';
      case DioExceptionType.receiveTimeout:
        return '服务器响应超时，请稍后重试';
      case DioExceptionType.connectionError:
        return '无法连接到服务器，请确认服务已启动';
      case DioExceptionType.badCertificate:
        return '服务器证书校验失败';
      default:
        return '网络请求失败：${e.message ?? '未知错误'}';
    }
  }

  String _errorMessage(dynamic decoded, int code) {
    if (decoded is Map) {
      final m = asMap(decoded);
      final msg = strOrNull(m['error']) ?? strOrNull(m['message']);
      if (msg != null) return msg;
    }
    if (decoded is String && decoded.trim().isNotEmpty && decoded.length < 300) {
      return decoded.trim();
    }
    return '请求失败（HTTP $code）';
  }

  Future<dynamic> _get(String path,
          {Map<String, dynamic>? query,
          bool longPoll = false,
          bool ranch = false,
          bool useAccountHeader = true,
          String? overrideUrl,
          String? overrideToken}) =>
      _send('GET', path,
          query: query,
          longPoll: longPoll,
          ranch: ranch,
          useAccountHeader: useAccountHeader,
          overrideUrl: overrideUrl,
          overrideToken: overrideToken);

  Future<dynamic> _post(String path,
          {Object? body,
          bool longPoll = false,
          bool ranch = false,
          String? overrideUrl,
          String? overrideToken}) =>
      _send('POST', path,
          body: body ?? const <String, dynamic>{},
          longPoll: longPoll,
          ranch: ranch,
          overrideUrl: overrideUrl,
          overrideToken: overrideToken);

  Future<dynamic> _delete(String path) => _send('DELETE', path, body: null);

  // ---------------------------------------------------------------- 服务器与认证

  Future<ServerVersionInfo> fetchGameVersion(String rawUrl) async {
    final url = normalizeBaseUrl(rawUrl);
    if (url == null) throw const ApiException('请输入有效的服务器地址');
    final data = await _get('/api/game-version', overrideUrl: url);
    return ServerVersionInfo.parse(data);
  }

  Future<LoginResult> login(String rawUrl, String username, String password) async {
    final url = normalizeBaseUrl(rawUrl);
    if (url == null) throw const ApiException('请输入有效的服务器地址');
    final data = await _post('/api/login',
        body: {'username': username, 'password': password}, overrideUrl: url);
    return LoginResult.parse(data);
  }

  Future<bool> validateToken(String rawUrl, String token) async {
    final url = normalizeBaseUrl(rawUrl);
    if (url == null) return false;
    try {
      await _get('/api/auth/validate', overrideUrl: url, overrideToken: token);
      return true;
    } on ApiException catch (e) {
      if (e.httpCode == 401 || e.httpCode == 403) return false;
      rethrow;
    }
  }

  Future<String> fetchUserMe(String rawUrl, String token) async {
    final url = normalizeBaseUrl(rawUrl);
    if (url == null) return '';
    final data = await _get('/api/user/me', overrideUrl: url, overrideToken: token);
    final m = asMap(data);
    return strOr(m['username'], strOr(m['name'], ''));
  }

  Future<void> logout() => _post('/api/logout');

  // ---------------------------------------------------------------- 账号

  Future<List<AccountItem>> fetchAccounts() async {
    final data = await _get('/api/accounts');
    final list = data is List ? data : asList(asMap(data)['accounts']);
    return list.map((e) => AccountItem.parse(e)).toList();
  }

  Future<void> startAccount(String accountId) =>
      _post('/api/accounts/${Uri.encodeComponent(accountId)}/start');

  Future<void> stopAccount(String accountId) =>
      _post('/api/accounts/${Uri.encodeComponent(accountId)}/stop');

  Future<void> deleteAccount(String accountId) =>
      _delete('/api/accounts/${Uri.encodeComponent(accountId)}');

  Future<void> saveAccount(Map<String, dynamic> payload) =>
      _post('/api/accounts', body: payload);

  Future<List<AccountLogEvent>> fetchAccountLogs({int limit = 50}) async {
    final data = await _get('/api/account-logs', query: {'limit': limit});
    final list = data is List ? data : asList(asMap(data)['logs']);
    return list.map((e) => AccountLogEvent.parse(e)).toList();
  }

  // ---------------------------------------------------------------- 状态与日志

  Future<StatusSnapshot> fetchStatus(String accountId) async {
    final data = await _get('/api/status');
    return StatusSnapshot.parse(accountId, data);
  }

  Future<int> fetchDiamond() async {
    final data = await _get('/api/diamond');
    if (data is num) return data.toInt();
    final m = asMap(data);
    return intOr(m['diamond'], intOr(m['count'], 0));
  }

  Future<dynamic> fetchDailyGifts() => _get('/api/daily-gifts');

  Future<List<RunLogEntry>> fetchLogs({int limit = 120}) async {
    final data = await _get('/api/logs', query: {'limit': limit});
    // 服务端可能返回顶层数组
    final list = data is List ? data : asList(asMap(data)['logs']);
    return list.map((e) => RunLogEntry.parse(e)).toList();
  }

  Future<void> clearLogs() => _delete('/api/logs');

  Future<void> buyFertilizer(String type, int count) =>
      _post('/api/fertilizer/buy', body: {'type': type, 'count': count});

  // ---------------------------------------------------------------- 农场与背包

  Future<LandsPayload> fetchLands() async {
    final data = await _get('/api/lands');
    return LandsPayload.parse(data);
  }

  /// opType 取值只能是 all / harvest / clear / plant / upgrade
  /// 注意：浇水、除草、除虫在服务端统一由 clear 处理，不要拆成三个操作
  Future<dynamic> operateFarm(String opType, {int? landId}) {
    return _post('/api/farm/operate', body: {
      'opType': opType,
      if (landId != null) 'landId': landId,
    });
  }

  Future<dynamic> fertilizeLand(int landId, String fertilizerType) =>
      _post('/api/farm/fertilize',
          body: {'landId': landId, 'fertilizerType': fertilizerType});

  Future<dynamic> fertilizeAll(String fertilizerType) =>
      _post('/api/farm/fertilize-all', body: {'fertilizerType': fertilizerType});

  Future<BagPayload> fetchBag() async {
    final data = await _get('/api/bag');
    return BagPayload.parse(data);
  }

  Future<dynamic> useBagItem({required int itemId, required int count, int uid = 0}) =>
      _post('/api/bag/use', body: {'itemId': itemId, 'count': count, 'uid': uid});

  Future<dynamic> sellBagItems(List<Map<String, dynamic>> items) =>
      _post('/api/bag/sell', body: {'items': items});

  Future<dynamic> lockBagItems(List<int> uids, bool locked) =>
      _post('/api/bag/lock', body: {'itemUids': uids, 'locked': locked});

  // ---------------------------------------------------------------- 设置与自动化

  Future<Map<String, dynamic>> fetchSettings() async {
    final data = await _get('/api/settings');
    return asMap(data);
  }

  Future<dynamic> saveSettings(Map<String, dynamic> payload) =>
      _post('/api/settings/save', body: payload);

  Future<Map<String, dynamic>> fetchScheduler() async {
    final data = await _get('/api/scheduler');
    return asMap(data);
  }

  Future<List<Map<String, dynamic>>> fetchSeeds() async {
    final data = await _get('/api/seeds');
    final list = data is List ? data : asList(asMap(data)['seeds']);
    return list.map((e) => asMap(e)).toList();
  }

  // ---------------------------------------------------------------- 好友

  Future<List<Map<String, dynamic>>> fetchFriends({bool forceSync = false}) async {
    final data = await _get('/api/friends',
        query: forceSync ? {'forceSync': 'true'} : null, longPoll: true);
    final list = data is List ? data : asList(asMap(data)['friends']);
    return list.map((e) => asMap(e)).toList();
  }

  Future<dynamic> fetchFriendLands(String friendGid) =>
      _get('/api/friend/${Uri.encodeComponent(friendGid)}/lands');

  Future<dynamic> operateFriend(String friendGid, String opType) => _post(
        '/api/friend/${Uri.encodeComponent(friendGid)}/op',
        body: {'opType': opType},
      );

  Future<List<Map<String, dynamic>>> fetchInteractRecords() async {
    final data = await _get('/api/interact-records');
    final list = data is List ? data : asList(asMap(data)['records']);
    return list.map((e) => asMap(e)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchFriendBlacklist() async {
    final data = await _get('/api/friend-blacklist');
    final list = data is List ? data : asList(asMap(data)['blacklist']);
    return list.map((e) => asMap(e)).toList();
  }

  Future<dynamic> toggleFriendBlacklist(String gid) =>
      _post('/api/friend-blacklist/toggle', body: {'gid': gid});

  // ---------------------------------------------------------------- 牧场

  Future<Map<String, dynamic>> fetchRanch({String view = 'animals', String? shopId, String? hostGid}) async {
    final data = await _get('/api/ranch', ranch: true, query: {
      'view': view,
      if (shopId != null) 'shopId': shopId,
      if (hostGid != null) 'hostGid': hostGid,
    });
    return asMap(data);
  }

  /// 牧场操作统一走这里。action 例如 feed / upgrade / release，
  /// 关键消费类操作上游要求先 quote 拿签名再提交。
  Future<Map<String, dynamic>> ranchQuote(String action, Map<String, dynamic> input) async {
    final data = await _post('/api/ranch/$action/quote', body: input, ranch: true);
    return asMap(data);
  }

  Future<Map<String, dynamic>> ranchAction(
    String action,
    Map<String, dynamic> input, {
    Map<String, dynamic>? expected,
  }) async {
    final data = await _post(
      '/api/ranch/$action',
      ranch: true,
      body: {
        ...input,
        if (expected != null) 'expected': expected,
      },
    );
    return asMap(data);
  }

  Future<Map<String, dynamic>> fetchRanchAutomationOptions() async {
    final data = await _get('/api/ranch/automation-options');
    return asMap(data);
  }

  // ---------------------------------------------------------------- 宠物

  Future<Map<String, dynamic>> fetchPets() async {
    final data = await _get('/api/pets');
    return asMap(data);
  }

  Future<dynamic> deployPet(String dogId) => _post('/api/pets/deploy', body: {'dogId': dogId});

  Future<dynamic> withdrawPet() => _post('/api/pets/withdraw');

  Future<dynamic> usePetFood(int itemId, int count) =>
      _post('/api/pets/food/use', body: {'itemId': itemId, 'count': count, 'uid': 0});

  Future<dynamic> claimDogSkillGift() => _post('/api/dog/skill-gifts/claim');

  // ---------------------------------------------------------------- 商城

  Future<Map<String, dynamic>> fetchPropsShop() async {
    final data = await _get('/api/props-shop');
    return asMap(data);
  }

  Future<Map<String, dynamic>> fetchGameMall({required String slotType, int subSlotType = 1}) async {
    final data = await _get('/api/game-mall',
        query: {'slotType': slotType, 'subSlotType': subSlotType});
    return asMap(data);
  }

  Future<dynamic> purchasePropsShop(Map<String, dynamic> payload) =>
      _post('/api/props-shop/purchase', body: payload);

  Future<dynamic> purchaseGameMall(Map<String, dynamic> payload) =>
      _post('/api/game-mall/purchase', body: payload);

  Future<Map<String, dynamic>> fetchMysteryShop() async {
    final data = await _get('/api/mystery-shop');
    return asMap(data);
  }

  Future<dynamic> purchaseMysteryShop(Map<String, dynamic> payload) =>
      _post('/api/mystery-shop/purchase', body: payload);

  // ---------------------------------------------------------------- 节气日历

  Future<Map<String, dynamic>> fetchSolarCalendar() async {
    final data = await _get('/api/solar-calendar');
    return asMap(data);
  }

  Future<dynamic> solarCalendarAction(String action, Map<String, dynamic> body) =>
      _post('/api/solar-calendar/$action', body: body);

  // ---------------------------------------------------------------- 活动中心

  /// 活动中心接口路径多且结构各异，这里提供一个通用出口，
  /// 具体页面按需传 path / body，不用为每个活动都写一个方法。
  Future<Map<String, dynamic>> activityGet(String path) async {
    final data = await _get(path);
    return asMap(data);
  }

  Future<dynamic> activityPost(String path, [Map<String, dynamic>? body]) =>
      _post(path, body: body ?? const <String, dynamic>{});

  Future<Map<String, dynamic>> fetchActivityCenter() async {
    final data = await _get('/api/activity-center/activities');
    return asMap(data);
  }

  Future<Map<String, dynamic>> fetchRanchActivities() async {
    final data = await _get('/api/activity-center/ranch-activities');
    return asMap(data);
  }
}
