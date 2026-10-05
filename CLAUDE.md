# CLAUDE.md: development rules for Ledgerly

Read this before making any change. Before calling a change done, run the Definition of Done checklist at the end.

## 0. How this project is built and tested

- **The development machine has no Flutter.** Never run `flutter` or `dart` commands. Check code by reading it.
- **GitHub Actions is the build** (`.github/workflows/build.yml`). It runs, in order:
  - `flutter create` (to generate the platform folders)
  - `flutter analyze`
  - `flutter test`
  - the web build and the APK build, both deployed to GitHub Pages
- **Every change must compile and pass tests in CI.**

### Known name clash: `Category`
`package:flutter/foundation.dart` exports a `Category` annotation that clashes with our model.

Any file that imports both must hide Flutter's version:
```dart
import 'package:flutter/foundation.dart' hide Category;
```

`material.dart` and `widgets.dart` don't re-export it, so files importing only those are fine.

### No code generation
- No `build_runner`, Hive adapters, `freezed` or `gen-l10n`.
- Models use hand-written `toMap` / `fromMap` and are stored as plain maps in Hive boxes.

### The app must also run on the web
The web build is the preview the user tests with, so:
- Guard phone-only plugins with `kIsWeb` (biometrics, FLAG_SECURE).
- Don't use `dart:io` outside conditional-import files in `lib/core/platform/`.

### Platform folders
- `android/` and `web/` are generated, not committed.
- The only exceptions are files we customise, which are listed in `.gitignore`.
- To customise another platform file, commit the full file and un-ignore it in `.gitignore`.

## 1. Architecture

| Folder | Holds |
|---|---|
| `lib/domain/` | Pure Dart logic (balances, cycles, queries, transfer rules, parsing). No Flutter imports. Every file has unit tests in `test/`. |
| `lib/data/` | Hive storage. `Db.apply(ChangeSet)` is the **only** write path, and it returns the inverse `ChangeSet`, which is what Undo applies. |
| `lib/state/` | `ChangeNotifier` stores. |
| `lib/ui/` | Widgets only. |

### Stores (`lib/state/`)
- Every write returns a `WriteResult`.
- If a write fails, the store reloads from disk and calls `ErrorReporter.saveFailed()`. It never throws to the UI.
- **Derived data is computed in the store and memoised per data version:** totals, breakdowns, day groups and cycle ranges. Never recompute it inside `build()`.

### Undo
- Every delete must offer Undo: keep the inverse `ChangeSet` from `WriteResult.undo` and pass it to `store.undo()`.
- Give each delete its own inverse. Never share one Undo slot between deletes.

### Transfers
- A transfer is always exactly two `Txn` legs that share one `transferId`.
- Never write one leg without the other.

## 2. Strings

- No raw string literals as user-visible text. Every string comes from `AppStrings` (`lib/core/strings/app_strings.dart`).
- Only English exists today. Keep it in that one class so other languages can be added later.

## 3. Theme

- **Colours:** come from `context.colors` (the `AppColors` theme extension, `lib/core/theme/tokens.dart`) or from `Theme.of(context).colorScheme`.
- **No `Colors.xxx` literals**, except `Colors.white` on top of the gradient hero card and `Colors.transparent`.
- **Semantic colours:** income, expense and transfer colours exist in both palettes. Use the tokens.
- **Opacity:** use `Color.withValues(alpha: …)`, never `withOpacity`.

## 4. Performance (the app must feel instant)

### Drawing
- **No** `BackdropFilter`, blur, looping animations or animated gradients.
- **Lists:** lazy lists use sliver builders, give every row a stable `ValueKey(id)`, and use `findChildIndexCallback` when the list's length can change.
- **Row animations:** no per-row entrance animation inside an `itemBuilder`.
- **Isolate expensive paint:** wrap charts, the hero card and the keypad in a `RepaintBoundary`.

### Rebuilds
- Prefer `context.select` over `context.watch` for narrow rebuilds.
- Use `const` widgets wherever possible.

### Motion
- Durations come from `Motion` (`lib/core/theme/motion.dart`).
- Respect `MediaQuery.disableAnimationsOf(context)`.

## 5. UI safety

- **Overflow:** any `Text` showing user-entered content gets `maxLines` and `overflow: TextOverflow.ellipsis`.
- **After an `await`:** check `context.mounted` (or `mounted`) before using a `BuildContext`.
- **Destructive actions:** ask for confirmation, use a red button, then offer Undo.

## 6. Versioning

The version lives in **two places**, and they must change together:
- `pubspec.yaml` `version:`
- `lib/core/app_info.dart` `AppInfo.version`

Each milestone gets a version bump and a dated `CHANGELOG.md` entry.

## Definition of Done

- [ ] All new text comes from `AppStrings`.
- [ ] Looks correct in light and dark mode, using tokens only.
- [ ] User-entered text can't overflow.
- [ ] Writes use `WriteResult`, and every delete offers Undo.
- [ ] `mounted` is checked after every `await`.
- [ ] New `domain/` logic has unit tests.
- [ ] No `dart:io` or phone-only plugin is used without a web-safe guard.
- [ ] The version is bumped and `CHANGELOG.md` updated (at the end of a milestone).
