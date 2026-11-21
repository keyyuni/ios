/// 数字与时间格式化。iOS 上没有 intl 也能跑，保持零依赖。
library;

/// 大数字缩写：12345 -> 1.2万，123456789 -> 1.2亿
String compactNum(num v) {
  final n = v.abs();
  if (n >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}亿';
  if (n >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
  return v.toStringAsFixed(0);
}

/// 千分位：1234567 -> 1,234,567
String groupedNum(num v) {
  final s = v.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// 秒 -> 倒计时文本：3700 -> 1小时1分
String countdownText(int seconds) {
  if (seconds <= 0) return '已成熟';
  final d = seconds ~/ 86400;
  final h = (seconds % 86400) ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (d > 0) return '$d天$h小时';
  if (h > 0) return '$h小时$m分';
  if (m > 0) return '$m分$s秒';
  return '$s秒';
}

/// 毫秒时间戳 -> HH:mm:ss
String clockText(int? ms) {
  if (ms == null || ms <= 0) return '--:--';
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// 时间戳 -> 相对时间：刚刚 / 3分钟前 / 2小时前
String agoText(int? ms) {
  if (ms == null || ms <= 0) return '';
  final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  return '${diff.inDays}天前';
}
