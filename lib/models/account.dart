/// Account type is a label only — it groups accounts in lists and never changes a calculation.
enum AccountType {
  current,
  savings,
  cash,
  creditCard,
  wallet,
  investment,
  other;

  static AccountType parse(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => AccountType.other);
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.currency,
    required this.emoji,
    required this.color,
    required this.type,
    required this.sortOrder,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String currency;
  final String emoji;
  final int color;
  final AccountType type;
  final int sortOrder;
  final DateTime createdAt;

  Account copyWith({
    String? name,
    String? currency,
    String? emoji,
    int? color,
    AccountType? type,
    int? sortOrder,
  }) =>
      Account(
        id: id,
        name: name ?? this.name,
        currency: currency ?? this.currency,
        emoji: emoji ?? this.emoji,
        color: color ?? this.color,
        type: type ?? this.type,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'currency': currency,
        'emoji': emoji,
        'color': color,
        'type': type.name,
        'sortOrder': sortOrder,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Account.fromMap(Map<String, dynamic> m) => Account(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        currency: (m['currency'] as String?) ?? 'LKR',
        emoji: (m['emoji'] as String?) ?? '💰',
        color: (m['color'] as num?)?.toInt() ?? 0xFF2563EB,
        type: AccountType.parse(m['type'] as String?),
        sortOrder: (m['sortOrder'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (m['createdAt'] as num?)?.toInt() ?? 0,
        ),
      );
}
