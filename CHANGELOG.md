# Changelog

This file lists every Ledgerly release, newest first. It loosely follows the
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format, and dates are `YYYY-MM-DD`.

## [0.1.0] - 2026-10-05

First milestone (M1): the foundation and the core money flow.

### Added

**Getting started**
- A welcome screen on first launch, where you create your first account and pick its currency.
- 20 starter categories, each with its own emoji and colour.

**Adding transactions**
- An **Add sheet with its own number keypad**, for Expense, Income or Transfer.
- Each transaction has a category, a description (filled in from the category until you edit it), a date and time, and optional notes.
- An **Exclude from totals** switch, for transactions you want to keep a record of without counting them.
- **Transfers between your own accounts.**
  - Each transfer is stored as one linked pair: money out of one account and into the other.
  - Accounts in different currencies ask for both the amount sent and the amount received.
  - Editing or deleting a transfer always changes both sides together.

**Home**
- An account switcher.
- A balance card with a **Month / All** toggle and a count-up animation.
- An accounts strip showing every account's balance, with totals per currency.
- A spending / income breakdown, as a donut chart with a ranked list.
- Your most recent transactions.

**Transactions**
- Transaction details, with Edit and Delete. Every delete can be undone.
- A basic Transactions tab, grouped by day with a total for each day. Search, filters and sorting come in 0.2.0.

**Accounts**
- Add, edit, switch, reorder and delete accounts.
- When you delete an account, you can move its transactions to another account or delete them.
- If the account you delete has transfers, the matching entries in your other accounts become plain income or expense rows. Their balances stay correct, and Undo restores the original transfers.

**Settings**
- Theme: System, Light or Dark.
- About, showing the version and build number.

**Testing builds**
- Every push builds a web preview and an APK, published to GitHub Pages.
