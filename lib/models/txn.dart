enum TxnType {
  income,
  expense,
  transfer;

  static TxnType parse(String? s) =>
      values.firstWhere((e) => e.name == s, orElse: () => TxnType.expense);
}

enum TransferDirection {
  outgoing,
  incoming;

  static TransferDirection? parse(String? s) {
    for (final v in values) {
      if (v.name == s) return v;
    }
    return null;
  }
}

/// One row in an account's history.
///
/// A transfer is always **two** rows that share a [transferId]: an outgoing leg
/// in the source account (amount sent) and an incoming leg in the destination
/// (amount received — different when the currencies differ).
class Txn {
  const Txn({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    required this.createdAt,
    this.categoryId,
    this.notes,
    this.excluded = false,
    this.transferId,
    this.direction,
    this.counterAccountId,
    this.updatedAt,
  });

  final String id;
  final String accountId;
  final TxnType type;

  /// Always positive; the sign comes from [type] / [direction].
  final double amount;
  final String? categoryId;
  final String description;
  final DateTime date;
  final String? notes;

  /// "Exclude from totals". Has no effect on transfers (see [isCounted]).
  final bool excluded;
  final String? transferId;
  final TransferDirection? direction;
  final String? counterAccountId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get isTransfer => type == TxnType.transfer;

  /// Enforced here rather than only in the UI: an excluded flag on a transfer
  /// leg would leave two accounts permanently disagreeing, so it is ignored.
  bool get isCounted => isTransfer || !excluded;

  /// Effect on this row's account balance.
  double get signedAmount => switch (type) {
        TxnType.income => amount,
        TxnType.expense => -amount,
        TxnType.transfer =>
          direction == TransferDirection.outgoing ? -amount : amount,
      };

  static const Object _unset = Object();

  Txn copyWith({
    String? accountId,
    TxnType? type,
    double? amount,
    Object? categoryId = _unset,
    String? description,
    DateTime? date,
    Object? notes = _unset,
    bool? excluded,
    Object? transferId = _unset,
    Object? direction = _unset,
    Object? counterAccountId = _unset,
    Object? updatedAt = _unset,
  }) =>
      Txn(
        id: id,
        accountId: accountId ?? this.accountId,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        categoryId: identical(categoryId, _unset)
            ? this.categoryId
            : categoryId as String?,
        description: description ?? this.description,
        date: date ?? this.date,
        notes: identical(notes, _unset) ? this.notes : notes as String?,
        excluded: excluded ?? this.excluded,
        transferId: identical(transferId, _unset)
            ? this.transferId
            : transferId as String?,
        direction: identical(direction, _unset)
            ? this.direction
            : direction as TransferDirection?,
        counterAccountId: identical(counterAccountId, _unset)
            ? this.counterAccountId
            : counterAccountId as String?,
        createdAt: createdAt,
        updatedAt: identical(updatedAt, _unset)
            ? this.updatedAt
            : updatedAt as DateTime?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'accountId': accountId,
        'type': type.name,
        'amount': amount,
        'categoryId': categoryId,
        'description': description,
        'date': date.millisecondsSinceEpoch,
        'notes': notes,
        'excluded': excluded,
        'transferId': transferId,
        'direction': direction?.name,
        'counterAccountId': counterAccountId,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
      };

  factory Txn.fromMap(Map<String, dynamic> m) {
    DateTime? ms(Object? v) =>
        v == null ? null : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());
    return Txn(
      id: m['id'] as String,
      accountId: (m['accountId'] as String?) ?? '',
      type: TxnType.parse(m['type'] as String?),
      amount: ((m['amount'] as num?) ?? 0).toDouble(),
      categoryId: m['categoryId'] as String?,
      description: (m['description'] as String?) ?? '',
      date: ms(m['date']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      notes: m['notes'] as String?,
      excluded: (m['excluded'] as bool?) ?? false,
      transferId: m['transferId'] as String?,
      direction: TransferDirection.parse(m['direction'] as String?),
      counterAccountId: m['counterAccountId'] as String?,
      createdAt: ms(m['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: ms(m['updatedAt']),
    );
  }
}
