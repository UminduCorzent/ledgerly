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
