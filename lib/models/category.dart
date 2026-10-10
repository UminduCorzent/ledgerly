/// Categories are shared by every account and untyped: any category can be
/// used for income or expense in any account. Transactions link to them by id, so a rename shows
/// everywhere immediately.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.sortOrder,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String emoji;
  final int color;
  final int sortOrder;
  final DateTime createdAt;

  Category copyWith({
    String? name,
    String? emoji,
    int? color,
    int? sortOrder,
  }) =>
      Category(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        color: color ?? this.color,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'color': color,
        'sortOrder': sortOrder,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Category.fromMap(Map<String, dynamic> m) => Category(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        emoji: (m['emoji'] as String?) ?? '📌',
        color: (m['color'] as num?)?.toInt() ?? 0xFF94A3B8,
        sortOrder: (m['sortOrder'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (m['createdAt'] as num?)?.toInt() ?? 0,
        ),
      );
}
