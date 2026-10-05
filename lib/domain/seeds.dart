/// Starter categories for every new account: (emoji, colour). Names come from
/// `AppStrings.seedCategoryNames` in the same order.
const List<(String, int)> kSeedCategories = [
  ('🍽️', 0xFFF97316), // Food
  ('🚗', 0xFF3B82F6), // Transport
  ('🛒', 0xFF22C55E), // Groceries
  ('🛍️', 0xFFF43F5E), // Shopping
  ('💡', 0xFFEAB308), // Bills
  ('🏠', 0xFFEF4444), // Rent
  ('🎬', 0xFFA855F7), // Entertainment
  ('🏥', 0xFF14B8A6), // Health
  ('📚', 0xFF0EA5E9), // Education
  ('🍕', 0xFFFB923C), // Dining Out
  ('✈️', 0xFF06B6D4), // Travel
  ('⛽', 0xFF78716C), // Fuel
  ('🛡️', 0xFF64748B), // Insurance
  ('📱', 0xFF8B5CF6), // Subscriptions
  ('🏋️', 0xFF10B981), // Fitness
  ('🎁', 0xFFEC4899), // Gift
  ('💵', 0xFF16A34A), // Salary
  ('💻', 0xFF6366F1), // Freelance
  ('📈', 0xFFF59E0B), // Investment
  ('📌', 0xFF94A3B8), // Other
];

/// Index of the default category per type in [kSeedCategories].
const int kSeedExpenseDefault = 0; // Food
const int kSeedIncomeDefault = 16; // Salary

/// Emoji offered for accounts.
const List<String> kAccountEmoji = [
  '💰', '🏦', '💳', '👛', '💵', '💶', '💷', '💴', '🪙', '📈',
  '🏠', '🚗', '✈️', '🎓', '🏥', '🛒', '🎁', '💼', '🧾', '📊',
  '🏧', '💸', '🐷', '🔒', '⭐', '🌴', '🛍️', '⚽', '🎮', '🧳',
];

/// Emoji offered for categories.
const List<String> kCategoryEmoji = [
  '🍽️', '🍕', '☕', '🍔', '🛒', '🍎', '🚗', '⛽', '🚌', '🚕',
  '✈️', '🏠', '💡', '💧', '📱', '🌐', '🛍️', '👕', '👟', '💄',
  '🏥', '💊', '🏋️', '🎬', '🎮', '🎵', '📚', '🎓', '🎁', '🐶',
  '👶', '🛡️', '🔧', '🧾', '💳', '🏦', '📈', '💵', '💻', '💼',
  '🤝', '🔁', '❤️', '🎉', '🧳', '⚽', '🪴', '📌',
];

/// Colours offered for accounts and categories.
const List<int> kPalette = [
  0xFF2563EB, 0xFF0EA5E9, 0xFF06B6D4, 0xFF10B981,
  0xFF22C55E, 0xFF84CC16, 0xFFEAB308, 0xFFF59E0B,
  0xFFF97316, 0xFFEF4444, 0xFFF43F5E, 0xFFEC4899,
  0xFFD946EF, 0xFF8B5CF6, 0xFF6366F1, 0xFF64748B,
];
