import '../../core/json.dart';

/// 背包物品
class BagItem {
  final String key;
  final int id;
  final int uid;
  final String name;
  final String image;
  final int count;
  final String category;
  final int itemType;
  final bool sellable;
  final int price;
  final String priceUnit;
  final bool locked;
  final String description;
  final String interactionType;
  final String hoursText;

  const BagItem({
    required this.key,
    required this.id,
    required this.uid,
    required this.name,
    required this.image,
    required this.count,
    required this.category,
    required this.itemType,
    required this.sellable,
    required this.price,
    required this.priceUnit,
    required this.locked,
    required this.description,
    required this.interactionType,
    required this.hoursText,
  });

  factory BagItem.parse(dynamic raw) {
    final m = asMap(raw);
    final id = intOr(m['id'], 0);
    final uid = intOr(m['uid'], 0);
    return BagItem(
      key: strOrNull(m['key']) ?? '$id:$uid',
      id: id,
      uid: uid,
      name: strOr(m['name'], '未知道具'),
      image: strOr(m['image'], ''),
      count: intOr(m['count'], 0),
      category: strOr(m['category'], 'item'),
      itemType: intOr(m['itemType'], 0),
      sellable: boolOr(m['sellable'], false),
      price: intOr(m['price'], 0),
      priceUnit: strOr(m['priceUnit'], '金'),
      locked: boolOr(m['locked'], false),
      description: strOr(m['description'], ''),
      interactionType: strOr(m['interactionType'], ''),
      hoursText: strOr(m['hoursText'], ''),
    );
  }
}

/// 系统道具（化肥桶、罐头桶这类常驻资源）
class BagSystemItem {
  final int id;
  final int count;
  final String name;
  final String interactionType;
  final String hoursText;

  const BagSystemItem({
    required this.id,
    required this.count,
    required this.name,
    required this.interactionType,
    required this.hoursText,
  });

  factory BagSystemItem.parse(dynamic raw) {
    final m = asMap(raw);
    return BagSystemItem(
      id: intOr(m['id'], 0),
      count: intOr(m['count'], 0),
      name: strOr(m['name'], ''),
      interactionType: strOr(m['interactionType'], ''),
      hoursText: strOr(m['hoursText'], ''),
    );
  }
}

class BagPayload {
  final List<BagItem> items;
  final List<BagSystemItem> systemItems;

  const BagPayload({required this.items, required this.systemItems});

  /// 按名字找系统道具数量，例如「化肥」「罐头桶」，找不到返回 0
  int systemCount(String nameKeyword) {
    for (final it in systemItems) {
      if (it.name.contains(nameKeyword)) return it.count;
    }
    return 0;
  }

  factory BagPayload.parse(dynamic raw) {
    final m = asMap(raw);
    return BagPayload(
      items: asList(m['items']).map((e) => BagItem.parse(e)).toList(),
      systemItems: asList(m['systemItems']).map((e) => BagSystemItem.parse(e)).toList(),
    );
  }
}
