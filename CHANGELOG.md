# Changelog

This file lists every Ledgerly release, newest first. It loosely follows the
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format, and dates are `YYYY-MM-DD`.

## [0.3.0] - 2026-10-05

Third milestone (M3): month cycles, App Lock and the rest of Settings.

### Added
- **Month cycle** per account (Settings → This account → Month cycle).
  - **Fixed day**: every month starts on day 1–31. In shorter months it falls on the last day.
  - **Payday**: each month starts on your own qualifying income.
    - Choose which categories count as payday, and a minimum amount.
    - A **cooldown** (default 20 days) stops a bonus or refund from starting a new month.
    - You can **pin** a start date if a payday isn't recorded.
    - Before your first payday, a fallback start day is used.
    - The latest cycle stays **open** ("25 Sep – ongoing") until the next payday is recorded.
    - Income marked "Exclude from totals" never starts a cycle.
  - The screen shows the current cycle and the most recent detected cycle starts.
  - The cycle drives "this month" everywhere:
    - the Home balance card and breakdown
    - the Transactions month navigator and the 12-month picker
    - the This month and Last month filter presets
  - Home shows **"Cycle running long · Day N"** when an open payday cycle is longer than your usual gap between paydays.
- **App Lock** (Settings → Security).
  - **4-digit PIN**, set up with a confirmation step. It's stored only as a salted PBKDF2-HMAC-SHA256 hash: 100,000 rounds on the phone, fewer in the web preview, and the round count is stored with the hash.
  - Turning the lock off requires your PIN. Changing your PIN requires your current PIN first.
  - **Lock screen** on launch, and when you return after the **auto-lock** time: immediately, 30 seconds, or 1, 5, 10 or 30 minutes (default 1 minute).
  - Locking closes any open sheet or page underneath.
  - **Lockout after wrong PINs**: 5 tries → 30 s, 8 → 2 min, 10 → 5 min, with a live countdown.
    - The lockout survives restarting the app.
  - **Biometric unlock** (phone only). The system prompt opens automatically on the lock screen, with the device PIN or pattern as a fallback.
    - Turning biometric unlock on or off needs a successful biometric check.
- **Screenshot blocking** on Android: no screenshots or screen recording, and no preview in the recent-apps screen. It's always on.

### Changed
- Android now uses `FlutterFragmentActivity` (required for the biometric prompt) and declares `USE_BIOMETRIC`.
- Date ranges for open cycles show "ongoing" instead of an end date.

## [0.2.0] - 2026-10-05

Second milestone (M2): the full Transactions tab and category management.

### Added
- **Transactions tab**
  - **Search** by description, category or notes. Results update as you type.
  - **Month navigator** (◂ October 2026 ▸) showing the month's In and Out totals.
    - Tap the month to pick one of the last 12 months, or All time.
    - Months follow the account's month cycle, so they stay in step once custom cycles arrive.
  - **Filter sheet** on one scrolling page, with a live "Show N results" button:
    - date presets (Today, This week, This month, Last month, Last 3 months, This year, All time) and a custom date range
    - type
    - accounts (to view several accounts together)
    - categories, with a search box when there are many
    - amount min / max, with a check that min isn't above max
    - Counting: All / Counted / Excluded
  - **Active filter chips**, each removable, including a chip for the Counting filter.
  - **Summary line** while filtering: the result count, income, expense, how many rows are excluded, and a warning when the results mix currencies.
  - **10 sort options**: newest, oldest, highest, lowest, category A–Z / Z–A, two type orders, account A–Z / Z–A. Your choice is remembered.
  - **Day headers** stay pinned at the top while you scroll, and show each day's net total. Only the date sorts group by day.
  - **Swipe left to delete** (with a confirmation), and **long-press to select** several rows: select all, delete selected. Every delete can be undone.
  - **Empty states** for a period with no transactions and for filters with no matches.
- **Home links**
  - The Income and Expense pills open the list filtered to that type, for the period shown on Home.
  - The › on a breakdown row opens that category's transactions.
- **Categories** (Settings → This account → Categories)
  - Add and edit, with a live preview chip, emoji grid and colour picker.
  - Names must be unique within an account.
  - Search, drag to reorder, and long-press to select several.
  - Delete moves the category's transactions to another category, or deletes them, with Undo.
  - You can't delete your last category.
- **Default categories**: choose which category Expense and Income start with in the Add sheet.
- **Settings** gains a **"This account"** group, tinted in the account's colour, with a Switch button. Each row in it carries a small account badge.

### Changed
- New categories go to the end of the list.
- Deleting a category clears any default category setting that pointed to it.
- The Add sheet's "More" category grid is now the shared category picker, with search.

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
