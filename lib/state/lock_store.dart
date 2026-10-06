import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

import '../data/db.dart';
import '../domain/pin_hasher.dart';
import 'error_reporter.dart';

String _hashInBackground(List<Object> args) =>
    hashPin(args[0] as String, iterations: args[1] as int);

bool _verifyInBackground(List<String> args) => verifyPin(args[0], args[1]);

/// App lock: PIN (PBKDF2 hash), optional biometrics, auto-lock timeout and
/// lockout after wrong PINs. Listens to the app lifecycle to lock on return.
class LockStore extends ChangeNotifier with WidgetsBindingObserver {
  LockStore(this._db);

  final Db _db;

  static const String _kEnabled = 'lock_enabled';
  static const String _kHash = 'lock_hash';
  static const String _kBio = 'lock_biometric';
  static const String _kTimeout = 'lock_timeout';
  static const String _kFailed = 'lock_failed';
  static const String _kUntil = 'lock_until';

  /// Auto-lock options in seconds (0 = immediately).
  static const List<int> timeoutOptions = [0, 30, 60, 300, 600, 1800];

  // PBKDF2 runs on the main thread in the browser (no isolates), so the web
  // preview uses fewer rounds to stay responsive. The count is stored in the
  // hash itself, so verification always uses whatever was used to create it.
  static int get _iterations => kIsWeb ? 20000 : 100000;

  bool _enabled = false;
  String? _hash;
  bool _biometric = false;
  int _timeout = 60;
  int _failed = 0;
  DateTime? _lockedUntil;
  bool _locked = false;
  DateTime? _backgroundAt;
  bool _authInProgress = false;
  bool? _bioAvailable;

  bool get enabled => _enabled;
  bool get biometricEnabled => _biometric;
  int get timeoutSeconds => _timeout;
  bool get locked => _locked;

  /// Remaining lockout after too many wrong PINs, or null.
  Duration? get lockoutRemaining {
    final until = _lockedUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    return left > Duration.zero ? left : null;
  }

  void load() {
    _enabled = _db.setting<bool>(_kEnabled) ?? false;
    _hash = _db.setting<String>(_kHash);
    if (_hash == null) _enabled = false;
    _biometric = _db.setting<bool>(_kBio) ?? false;
    _timeout = _db.setting<int>(_kTimeout) ?? 60;
    // Persisted so restarting the app doesn't reset the lockout.
    _failed = _db.setting<int>(_kFailed) ?? 0;
    final until = _db.setting<int>(_kUntil);
    _lockedUntil = until == null ? null : DateTime.fromMillisecondsSinceEpoch(until);
    _locked = _enabled; // a cold start always asks for the PIN
  }

  Future<void> _save(Map<String, Object?> values) async {
    try {
      for (final e in values.entries) {
        await _db.setSetting(e.key, e.value);
      }
    } catch (_) {
      ErrorReporter.saveFailed();
    }
  }

  // ------------------------------------------------------------------- PIN

  /// Checks [pin] with lockout. Returns true when it matches.
  Future<bool> verify(String pin) async {
    final stored = _hash;
    if (stored == null || lockoutRemaining != null) return false;
    final ok = await compute(_verifyInBackground, [pin, stored]);
    if (ok) {
      _failed = 0;
      _lockedUntil = null;
    } else {
      _failed++;
      final wait = lockoutFor(_failed);
      _lockedUntil = wait == null ? null : DateTime.now().add(wait);
    }
    notifyListeners();
    await _save({_kFailed: _failed, _kUntil: _lockedUntil?.millisecondsSinceEpoch});
    return ok;
  }

  Future<bool> unlockWithPin(String pin) async {
    final ok = await verify(pin);
    if (ok) {
      _locked = false;
      notifyListeners();
    }
    return ok;
  }

  /// Turns the lock on with a new PIN.
  Future<void> enable(String pin) async {
    final hash = await compute(_hashInBackground, <Object>[pin, _iterations]);
    _hash = hash;
    _enabled = true;
    _locked = false;
    notifyListeners();
    await _save({_kHash: hash, _kEnabled: true});
  }

  Future<void> changePin(String pin) async {
    final hash = await compute(_hashInBackground, <Object>[pin, _iterations]);
    _hash = hash;
    notifyListeners();
    await _save({_kHash: hash});
  }

  Future<void> disable() async {
    _enabled = false;
    _biometric = false;
    _hash = null;
    _locked = false;
    notifyListeners();
    await _save({_kEnabled: false, _kHash: null, _kBio: false});
  }

  Future<void> setTimeout(int seconds) async {
    _timeout = seconds;
    notifyListeners();
    await _save({_kTimeout: seconds});
  }

  // ------------------------------------------------------------ biometrics

  final LocalAuthentication _auth = LocalAuthentication();

  /// False on the web and on devices without enrolled biometrics.
  Future<bool> biometricAvailable() async {
    if (kIsWeb) return false;
    final cached = _bioAvailable;
    if (cached != null) return cached;
    try {
      final supported = await _auth.isDeviceSupported();
      final can = await _auth.canCheckBiometrics;
      final enrolled = (await _auth.getAvailableBiometrics()).isNotEmpty;
      _bioAvailable = supported && can && enrolled;
    } catch (_) {
      _bioAvailable = false;
    }
    return _bioAvailable!;
  }

  /// Shows the system prompt. The device PIN/pattern is accepted as a fallback.
  Future<bool> authenticate(String reason) async {
    if (kIsWeb) return false;
    // The system prompt briefly backgrounds the app; don't treat that as leaving.
    _authInProgress = true;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
      );
    } catch (_) {
      return false;
    } finally {
      _authInProgress = false;
      _backgroundAt = null;
    }
  }

  Future<bool> unlockWithBiometric(String reason) async {
    if (!_biometric) return false;
    final ok = await authenticate(reason);
    if (ok) {
      _failed = 0;
      _lockedUntil = null;
      _locked = false;
      notifyListeners();
      await _save({_kFailed: 0, _kUntil: null});
    }
    return ok;
  }

  Future<void> setBiometric(bool on) async {
    _biometric = on;
    notifyListeners();
    await _save({_kBio: on});
  }

  // --------------------------------------------- actions that leave the app

  int _externalDepth = 0;
  DateTime? _externalStarted;

  /// An outside action that ran longer than this (e.g. the user wandered off
  /// from a file picker) still locks on return.
  static const Duration externalGrace = Duration(minutes: 5);

  /// Runs [action], which opens system UI the user asked for (file picker,
  /// save dialog, share sheet). Leaving the app for it doesn't count as
  /// backgrounding, so returning doesn't lock and the flow carries on.
  Future<T> runExternal<T>(Future<T> Function() action) async {
    _externalDepth++;
    _externalStarted ??= DateTime.now();
    try {
      return await action();
    } finally {
      _externalDepth--;
      if (_externalDepth == 0) {
        final started = _externalStarted;
        _externalStarted = null;
        _backgroundAt = null; // a late "resumed" event must not lock
        if (_enabled &&
            !_locked &&
            started != null &&
            DateTime.now().difference(started) > externalGrace) {
          _locked = true;
          notifyListeners();
        }
      }
    }
  }

  // ------------------------------------------------------------- lifecycle

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_enabled || _authInProgress || _externalDepth > 0) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _backgroundAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        {
          final at = _backgroundAt;
          _backgroundAt = null;
          if (at != null && !_locked && DateTime.now().difference(at).inSeconds >= _timeout) {
            _locked = true;
            notifyListeners();
          }
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }
}
