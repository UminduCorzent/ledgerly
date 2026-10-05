import 'package:flutter/widgets.dart';

/// Every user-visible string in the app.
///
/// English only for now. To add a language later, make this class abstract,
/// add one subclass per language, and pick one in [of] from the app locale.
/// Widgets never contain raw UI text.
class AppStrings {
  const AppStrings();

  static const AppStrings _en = AppStrings();

  static AppStrings of(BuildContext context) => _en;

  /// For code without a BuildContext (e.g. the global save-failure snackbar).
  static const AppStrings current = _en;

  // App
  String get appName => 'Ledgerly';

  // Tabs
  String get tabHome => 'Home';
  String get tabTransactions => 'Transactions';
  String get tabSettings => 'Settings';

  // Common actions
  String get add => 'Add';
  String get save => 'Save';
  String get update => 'Update';
  String get cancel => 'Cancel';
  String get delete => 'Delete';
  String get edit => 'Edit';
  String get undo => 'Undo';
  String get done => 'Done';
  String get more => 'More';
  String get seeAll => 'See all';
  String get continueLabel => 'Continue';
  String get close => 'Close';

  // Errors
  String get saveFailed => "Couldn't save — try again";
  String get startFailedTitle => "Couldn't start Ledgerly";
  String get startFailedBody =>
      "Your data couldn't be opened. Close the app and open it again. If this keeps happening, restart your phone.";
  String get retry => 'Retry';

  // Transaction types
  String get typeExpense => 'Expense';
  String get typeIncome => 'Income';
  String get typeTransfer => 'Transfer';
  String typeLabel(String name) => switch (name) {
        'income' => typeIncome,
        'transfer' => typeTransfer,
        _ => typeExpense,
      };

  // Welcome
  String get welcomeTitle => 'Welcome to Ledgerly';
  String get welcomeBody =>
      'Track what comes in and what goes out. Everything stays on this phone.';
  String get welcomeAccountLabel => 'Name your first account';
  String get welcomeAccountHint => 'e.g. Personal';
  String get welcomeAccountDefault => 'Personal';
  String get welcomeCurrencyLabel => 'Currency';
  String get welcomeStart => 'Get started';

  // Home
  String get periodMonth => 'Month';
  String get periodAll => 'All';
  String balanceForRange(String range) => 'Balance · $range';
  String get balanceAllTime => 'Balance · All time';
  String get statIncome => 'Income';
  String get statExpense => 'Expense';
  String get accountsTitle => 'Accounts';
  String get totalLabel => 'Total';
  String get breakdownTitle => 'Breakdown';
  String get breakdownSpending => 'Spending';
  String get breakdownIncome => 'Income';
  String get spentLabel => 'Spent';
  String get earnedLabel => 'Earned';
  String get otherSlice => 'Other';
  String get noSpendingInPeriod => 'No spending in this period';
  String get noIncomeInPeriod => 'No income in this period';
  String get recentTitle => 'Recent';
  String get homeEmptyTitle => 'No transactions yet';
  String get homeEmptyBody =>
      'Add your first one to see your balance and spending here.';
  String get homeEmptyAction => 'Add first transaction';
  String seeCategoryTransactions(String name) => 'See $name transactions';
  String get switchAccount => 'Switch account';

  // Add / edit sheet
  String get addTitle => 'Add transaction';
  String get editTitle => 'Edit transaction';
  String get amountSent => 'Sent';
  String get amountReceived => 'Received';
  String get fromAccount => 'From';
  String get toAccount => 'To';
  String get swapAccounts => 'Swap accounts';
  String get chooseAccount => 'Choose account';
  String get chooseCategory => 'Choose category';
  String get descriptionHint => 'Description';
  String get transferNoteHint => 'Note (optional)';
  String get notesHint => 'Notes';
  String get excludeTitle => 'Exclude from totals';
  String get excludeBody =>
      'Kept in your history and search, but skipped by every balance, total and chart.';
  String get today => 'Today';
  String get yesterday => 'Yesterday';
  String get backspace => 'Backspace';
  String get decimalPoint => 'Decimal point';
  String get enterAmount => 'Enter an amount above zero';
  String get enterReceived => 'Enter the amount received';
  String get pickTwoAccounts => 'Choose two different accounts';
  String get needSecondAccount => 'Add a second account to make transfers';
  String get pickCategory => 'Choose a category';
  String get transactionAdded => 'Transaction added';
  String get transactionUpdated => 'Transaction updated';
  String get transferDefaultDescription => 'Transfer';

  // Detail
  String get detailCategory => 'Category';
  String get detailAccount => 'Account';
  String get detailDescription => 'Description';
  String get detailDate => 'Date';
  String get detailNotes => 'Notes';
  String get detailFrom => 'From';
  String get detailTo => 'To';
  String get detailCounting => 'Counting';
  String get detailExcludedValue => 'Not counted in any balance, total or chart';
  String get detailCreated => 'Created';
  String get detailUpdated => 'Last edited';
  String get excludedPill => 'Excluded';
  String get deleteTxnTitle => 'Delete transaction?';
  String get deleteTxnBody => 'You can undo this right after.';
  String get deleteTransferBody =>
      'Both sides of this transfer will be deleted. You can undo this right after.';
  String get transactionDeleted => 'Transaction deleted';

  // Transactions tab
  String get txEmptyTitle => 'No transactions yet';
  String get txEmptyBody => 'Everything you add shows up here, grouped by day.';
  String get txComingSoon => 'Search, filters and sorting arrive in the next update.';

  // Accounts
  String get manageAccounts => 'Manage accounts';
  String get addAccount => 'Add account';
  String get editAccount => 'Edit account';
  String get reorder => 'Reorder';
  String get reorderHint => 'Drag to reorder';
  String get accountName => 'Account name';
  String get accountNameHint => 'e.g. Savings';
  String get accountType => 'Type';
  String get accountCurrency => 'Currency';
  String get accountIcon => 'Icon';
  String get accountColor => 'Colour';
  String get nameTooShort => 'Use at least 2 characters';
  String get nameTaken => 'You already have an account with this name';
  String get accountAdded => 'Account added';
  String get accountUpdated => 'Account updated';
  String get accountsReordered => 'Order saved';
  String switchedTo(String name) => 'Switched to $name';
  String get activeAccount => 'Active';
  String accountTypeLabel(String name) => switch (name) {
        'current' => 'Current',
        'savings' => 'Savings',
        'cash' => 'Cash',
        'creditCard' => 'Credit card',
        'wallet' => 'Digital wallet',
        'investment' => 'Investment',
        _ => 'Other',
      };
  String get deleteAccountTitle => 'Delete account?';
  String deleteAccountBody(String name) =>
      'Delete "$name" and its categories. You can undo this right after.';
  String deleteAccountHasTxns(int n) =>
      'It has $n transaction${n == 1 ? '' : 's'}. What should happen to them?';
  String get reassignTxns => 'Move them to another account';
  String get deleteTxns => 'Delete them';
  String get moveTo => 'Move to';
  String deleteAccountTransfersNote(int n) =>
      '$n transfer${n == 1 ? '' : 's'} involve this account. If you delete them, '
      'the matching entries in your other accounts become plain income or expense rows, '
      'so those balances stay correct.';
  String get cannotDeleteLast => "You can't delete your only account";
  String get accountDeleted => 'Account deleted';
  String get transfersCategory => 'Transfers';
  String transferFromAccount(String name) => 'Transfer from $name';
  String transferToAccount(String name) => 'Transfer to $name';

  // Settings
  String get settingsAppGroup => 'App · all accounts';
  String get settingsTheme => 'Theme';
  String get themeSystem => 'System';
  String get themeLight => 'Light';
  String get themeDark => 'Dark';
  String get settingsAccounts => 'Accounts';
  String accountsCount(int n) => '$n account${n == 1 ? '' : 's'}';
  String get settingsAbout => 'About';
  String aboutVersion(String v, String build, String sha) =>
      '$v · build $build · $sha';

  // Transactions tab (search, period, filters, sort, selection)
  String get search => 'Search';
  String get closeSearch => 'Close search';
  String get searchHint => 'Search description, category, notes';
  String get filters => 'Filters';
  String get sort => 'Sort';
  String get previousPeriod => 'Previous month';
  String get nextPeriod => 'Next month';
  String get allTime => 'All time';
  String get customRange => 'Custom range';
  String get choosePeriod => 'Choose period';
  String get periodIn => 'In';
  String get periodOut => 'Out';
  String resultsCount(int n) => '$n result${n == 1 ? '' : 's'}';
  String excludedCount(int n) => '$n excluded';
  String get mixedCurrencies => 'Mixed currencies — totals may not add up';
  String get noMatchesTitle => 'No matching transactions';
  String get noMatchesBody => 'Try removing a filter or choosing another period.';
  String get clearFilters => 'Clear filters';
  String emptyPeriodTitle(String period) => 'Nothing in $period';
  String get emptyPeriodBody => 'Transactions you add show up here, grouped by day.';
  String selectedCount(int n) => '$n selected';
  String get selectAll => 'Select all';
  String get clearSelection => 'Clear selection';
  String deleteTxnsTitle(int n) => 'Delete $n transaction${n == 1 ? '' : 's'}?';
  String get deleteTxnsBody =>
      'Transfers are deleted on both sides. You can undo this right after.';
  String txnsDeleted(int n) => '$n transaction${n == 1 ? '' : 's'} deleted';
  String accountsChip(int n) => '$n accounts';
  String get countedOnly => 'Counted only';
  String get excludedOnly => 'Excluded only';
  String amountAtLeast(String v) => '≥ $v';
  String amountAtMost(String v) => '≤ $v';
  String amountBetween(String a, String b) => '$a – $b';
  String removeFilter(String name) => 'Remove $name';

  // Filter sheet
  String get filterDate => 'Date';
  String get filterType => 'Type';
  String get filterAccounts => 'Accounts';
  String get filterCategories => 'Categories';
  String get filterAmount => 'Amount';
  String get filterCounting => 'Counting';
  String get countingAll => 'All';
  String get countingCounted => 'Counted';
  String get countingExcluded => 'Excluded';
  String get amountMin => 'Min';
  String get amountMax => 'Max';
  String get amountRangeError => 'Min is more than max';
  String get clear => 'Clear';
  String showResults(int n) => 'Show $n result${n == 1 ? '' : 's'}';
  String get categorySearchHint => 'Search categories';
  String get pickCustomRange => 'Pick dates…';
  String presetLabel(String name) => switch (name) {
        'today' => 'Today',
        'thisWeek' => 'This week',
        'thisMonth' => 'This month',
        'lastMonth' => 'Last month',
        'last3Months' => 'Last 3 months',
        'thisYear' => 'This year',
        _ => 'All time',
      };

  // Sort sheet
  String get sortTitle => 'Sort by';
  String sortLabel(String name) => switch (name) {
        'dateAsc' => 'Oldest first',
        'amountDesc' => 'Highest amount',
        'amountAsc' => 'Lowest amount',
        'categoryAsc' => 'Category A–Z',
        'categoryDesc' => 'Category Z–A',
        'typeAsc' => 'Type: income first',
        'typeDesc' => 'Type: transfers first',
        'accountAsc' => 'Account A–Z',
        'accountDesc' => 'Account Z–A',
        _ => 'Newest first',
      };

  // Categories
  String get categoriesTitle => 'Categories';
  String get addCategory => 'Add category';
  String get editCategory => 'Edit category';
  String get categoryName => 'Name';
  String get categoryNameHint => 'e.g. Coffee';
  String get categoryIcon => 'Icon';
  String get categoryColor => 'Colour';
  String get categoryAdded => 'Category added';
  String get categoryUpdated => 'Category updated';
  String get categoryNameTaken => 'You already have a category with this name';
  String usageCount(int n) => n == 0 ? 'No transactions' : '$n transaction${n == 1 ? '' : 's'}';
  String get categoriesReordered => 'Order saved';
  String get searchCategories => 'Search categories';
  String get noCategoryMatches => 'No categories match';
  String deleteCategoriesTitle(int n) => n == 1 ? 'Delete category?' : 'Delete $n categories?';
  String get deleteCategoriesBody => 'You can undo this right after.';
  String categoryHasTxns(int n) =>
      '${n == 1 ? 'It is' : 'They are'} used by $n transaction${n == 1 ? '' : 's'}. What should happen to ${n == 1 ? 'it' : 'them'}?';
  String get moveToCategory => 'Move them to another category';
  String get deleteTheirTxns => 'Delete those transactions';
  String get keepOneCategory => 'Keep at least one category';
  String categoriesDeleted(int n) => n == 1 ? 'Category deleted' : '$n categories deleted';
  String get deleteCategory => 'Delete category';

  // Default categories
  String get defaultCategories => 'Default categories';
  String get defaultCategoriesBody => 'Picked automatically when you add a transaction.';
  String get defaultExpense => 'Expense';
  String get defaultIncome => 'Income';
  String defaultSummary(String expense, String income) => 'Expense: $expense · Income: $income';

  // Settings — account group
  String settingsAccountGroup(String name) => 'This account · $name';
  String get switchLabel => 'Switch';
  String categoriesCount(int n) => '$n categor${n == 1 ? 'y' : 'ies'}';
  String accountScopeHint(String name) => 'Settings in this group change only $name.';

  // Month cycle
  String get monthCycle => 'Month cycle';
  String get cycleSummaryCalendar => 'Calendar month';
  String cycleSummaryDay(int d) => 'Starts on day $d';
  String get cycleSummaryPayday => 'Starts on payday';
  String get currentCycle => 'Current cycle';
  String get ongoing => 'ongoing';
  String runningLong(int day) => 'Cycle running long · Day $day';
  String get runningLongBody => 'Your next payday hasn’t been recorded yet.';
  String get cycleModeFixed => 'Fixed day';
  String get cycleModePayday => 'Payday';
  String get cycleModeFixedBody => 'Every month starts on the same day.';
  String get cycleModePaydayBody =>
      'Each month starts when your salary arrives, even if the date moves around.';
  String get startDayTitle => 'Start day';
  String get fallbackStartDayTitle => 'Fallback start day';
  String get fallbackStartDayBody => 'Used for dates before your first recorded payday.';
  String dayN(int d) => 'Day $d';
  String get calendarMonthHint => 'Day 1 means the calendar month.';
  String get shortMonthHint => 'In shorter months the cycle starts on the last day.';
  String get paydayCategories => 'Payday categories';
  String get paydayCategoriesAny => 'Any income counts';
  String paydayCategoriesCount(int n) => '$n selected';
  String get minimumAmount => 'Minimum amount';
  String get minimumAmountBody => 'Smaller income won’t start a new month.';
  String get cooldown => 'Cooldown';
  String get cooldownBody => 'Income within this many days of a payday stays in the same month.';
  String daysN(int n) => '$n day${n == 1 ? '' : 's'}';
  String get decrease => 'Decrease';
  String get increase => 'Increase';
  String get detectedStarts => 'Detected cycle starts';
  String get noDetectedStarts =>
      'No payday found yet. Add an income transaction, or pin a start date below.';
  String get pinnedManually => 'Pinned manually';
  String get pinStart => 'Pinned start date';
  String get pinStartBody => 'Use this if your latest payday isn’t recorded.';
  String get notSet => 'Not set';
  String get clearPin => 'Clear pinned date';

  // Security
  String get securityTitle => 'Security';
  String get appLock => 'App lock';
  String get appLockBody => 'Ask for your PIN when opening Ledgerly';
  String get biometricUnlock => 'Biometric unlock';
  String get biometricBody => 'Fingerprint or face, with your PIN as backup';
  String get biometricUnavailable => 'Biometric unlock isn’t available on this device';
  String get biometricReason => 'Unlock Ledgerly';
  String get biometricConfirmReason => 'Confirm it’s you';
  String get biometricFailed => 'Biometric check didn’t succeed';
  String get useBiometric => 'Use biometrics';
  String get changePin => 'Change PIN';
  String get autoLock => 'Auto-lock';
  String autoLockLabel(int seconds) => switch (seconds) {
        0 => 'Immediately',
        30 => 'After 30 seconds',
        60 => 'After 1 minute',
        300 => 'After 5 minutes',
        600 => 'After 10 minutes',
        _ => 'After 30 minutes',
      };
  String get autoLockBody => 'How long Ledgerly can stay in the background before it locks.';
  String get pinCreateTitle => 'Create a PIN';
  String get pinCreateBody => 'Choose 4 digits you’ll remember.';
  String get pinConfirmTitle => 'Confirm your PIN';
  String get pinConfirmBody => 'Enter the same 4 digits again.';
  String get pinMismatch => 'Those PINs didn’t match. Try again.';
  String get pinEnterTitle => 'Enter your PIN';
  String get pinCurrentTitle => 'Enter your current PIN';
  String get pinNewTitle => 'Choose a new PIN';
  String get pinWrong => 'Wrong PIN';
  String pinLockedOut(int seconds) => 'Too many tries. Try again in ${seconds}s.';
  String pinProgress(int n) => '$n of 4 digits entered';
  String get appLockOn => 'App lock is on';
  String get appLockOff => 'App lock is off';
  String get pinChanged => 'PIN changed';
  String get lockedTitle => 'Ledgerly is locked';

  // Seeded categories (order matters — see domain/seeds.dart)
  List<String> get seedCategoryNames => const [
        'Food',
        'Transport',
        'Groceries',
        'Shopping',
        'Bills',
        'Rent',
        'Entertainment',
        'Health',
        'Education',
        'Dining Out',
        'Travel',
        'Fuel',
        'Insurance',
        'Subscriptions',
        'Fitness',
        'Gift',
        'Salary',
        'Freelance',
        'Investment',
        'Other',
      ];
}
