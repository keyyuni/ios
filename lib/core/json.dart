/// 容错 JSON 读取工具。
///
/// 为什么需要这一层：上游服务端返回的字段经常出现
/// `null`、"null" 字符串、数字被序列化成字符串、字段缺失等情况。
/// 安卓版为此写了 optStringClean / optIntFlex / optLongFlex / optBoolFlex
/// 这一套辅助函数，这里 1:1 对应，保证解析行为和原版一致。
library;

/// 安全取 Map，非 Map 一律返回空 Map
Map<String, dynamic> asMap(dynamic v) {
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  return <String, dynamic>{};
}

/// 安全取 List，非 List 一律返回空 List
List<dynamic> asList(dynamic v) {
  if (v is List) return v;
  return const <dynamic>[];
}

/// 对应 optStringClean：去空白、过滤 "null"/"undefined" 字面量
String? strOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty || s == 'null' || s == 'undefined' || s == 'NaN') return null;
  return s;
}

String strOr(dynamic v, String fallback) => strOrNull(v) ?? fallback;

/// 对应 optLongFlex：支持 int / double / 数字字符串
int? intOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is bool) return v ? 1 : 0;
  final s = strOrNull(v);
  if (s == null) return null;
  return int.tryParse(s) ?? double.tryParse(s)?.toInt();
}

int intOr(dynamic v, int fallback) => intOrNull(v) ?? fallback;

double doubleOr(dynamic v, double fallback) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  final s = strOrNull(v);
  if (s == null) return fallback;
  return double.tryParse(s) ?? fallback;
}

/// 对应 optBoolFlex：支持 bool / 0-1 / "true"-"false"
bool boolOr(dynamic v, bool fallback) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = strOrNull(v)?.toLowerCase();
  if (s == null) return fallback;
  if (s == 'true' || s == '1' || s == 'yes') return true;
  if (s == 'false' || s == '0' || s == 'no') return false;
  return fallback;
}

/// 可空布尔：字段不存在时返回 null，用于区分"false"和"没这个字段"
bool? boolOrNull(dynamic v) {
  if (v == null) return null;
  return boolOr(v, false);
}
