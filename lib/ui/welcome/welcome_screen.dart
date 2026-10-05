import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format/money.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../models/account.dart';
import '../../state/ledger_store.dart';
import '../widgets/common.dart';

/// First launch: name the first account and pick its currency.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final TextEditingController _name =
      TextEditingController(text: AppStrings.current.welcomeAccountDefault);
  String _currency = kDefaultCurrency;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final s = AppStrings.of(context);
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = s.nameTooShort);
      return;
    }
    setState(() => _saving = true);
    final r = await context.read<LedgerStore>().createAccount(
          name: name,
          currency: _currency,
          emoji: '💰',
          color: 0xFF2563EB,
          type: AccountType.current,
        );
    if (!mounted) return;
    if (r.success) {
      HapticFeedback.lightImpact();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.card),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [c.heroA, c.heroB],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: const Text('💰', style: TextStyle(fontSize: 28)),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        s.welcomeTitle,
                        style: const TextStyle(
                          // White on the brand gradient in both themes.
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.welcomeBody,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(s.welcomeAccountLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [LengthLimitingTextInputFormatter(40)],
                  onChanged: (_) => setState(() => _error = null),
                  decoration: appInputDecoration(context, hint: s.welcomeAccountHint, errorText: _error),
                ),
                const SizedBox(height: 22),
                Text(s.welcomeCurrencyLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final cur in kCurrencies)
                      ChoiceChip(
                        label: Text('${cur.symbol}  ${cur.code}'),
                        selected: cur.code == _currency,
                        onSelected: (_) => setState(() => _currency = cur.code),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  currencyOf(_currency).name,
                  style: TextStyle(color: c.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _saving ? null : _start,
                  child: Text(s.welcomeStart),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
