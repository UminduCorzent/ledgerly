import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

// PIN hashing: PBKDF2-HMAC-SHA256 with a random 16-byte salt.
// Stored as `pbkdf2$<iterations>$<saltHex>$<hashHex>`, so the iteration count
// travels with the hash and verification never depends on today's default.

const int kPinLength = 4;

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

List<int> _unhex(String s) => [
      for (var i = 0; i + 1 < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16),
    ];

/// One 32-byte PBKDF2 block (dkLen = hash length, so a single block suffices).
Uint8List pbkdf2Sha256(List<int> password, List<int> salt, int iterations) {
  final hmac = Hmac(sha256, password);
  final block = Uint8List.fromList([...salt, 0, 0, 0, 1]);
  var u = hmac.convert(block).bytes;
  final out = Uint8List.fromList(u);
  for (var i = 1; i < iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < out.length; j++) {
      out[j] ^= u[j];
    }
  }
  return out;
}

String hashPin(String pin, {required int iterations, Random? random}) {
  final rng = random ?? Random.secure();
  final salt = List<int>.generate(16, (_) => rng.nextInt(256));
  final dk = pbkdf2Sha256(utf8.encode(pin), salt, iterations);
  return 'pbkdf2\$$iterations\$${_hex(salt)}\$${_hex(dk)}';
}

/// Constant-time comparison so timing doesn't reveal how many bytes matched.
bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

bool verifyPin(String pin, String stored) {
  final parts = stored.split(r'$');
  if (parts.length != 4 || parts[0] != 'pbkdf2') return false;
  final iterations = int.tryParse(parts[1]);
  if (iterations == null || iterations < 1) return false;
  final dk = pbkdf2Sha256(utf8.encode(pin), _unhex(parts[2]), iterations);
  return _constantTimeEquals(dk, _unhex(parts[3]));
}

/// Lockout after repeated wrong PINs: 5 → 30 s, 8 → 2 min, 10+ → 5 min.
Duration? lockoutFor(int failedAttempts) {
  if (failedAttempts >= 10) return const Duration(minutes: 5);
  if (failedAttempts >= 8) return const Duration(minutes: 2);
  if (failedAttempts >= 5) return const Duration(seconds: 30);
  return null;
}
