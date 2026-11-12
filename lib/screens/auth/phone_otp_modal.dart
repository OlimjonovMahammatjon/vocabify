import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../providers/auth_provider.dart';

/// Prompts the user to verify the 6-digit SMS OTP code after phone sign-up.
/// Returns `true` when verification succeeded and the session is active.
Future<bool> showPhoneOtpVerifyModal(
  BuildContext context, {
  required String phone,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _PhoneOtpVerifySheet(phone: phone),
  );
  return result == true;
}

class _PhoneOtpVerifySheet extends StatefulWidget {
  final String phone;

  const _PhoneOtpVerifySheet({required this.phone});

  @override
  State<_PhoneOtpVerifySheet> createState() => _PhoneOtpVerifySheetState();
}

class _PhoneOtpVerifySheetState extends State<_PhoneOtpVerifySheet> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  int _cooldownSeconds = 60;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final error = await context.read<AuthProvider>().verifyPhoneSignUpOtp(
      phone: widget.phone,
      token: _codeController.text,
    );

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    Navigator.of(context).pop(true);
  }

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final error = await context.read<AuthProvider>().resendPhoneSignUpOtp(
      widget.phone,
    );

    if (!mounted) return;
    setState(() => _isResending = false);

    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    _startCooldown();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final formattedPhone = AppHelpers.formatPhoneDisplay(widget.phone);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.brandDark : AppColors.brand)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.sms_outlined,
                        color: isDark ? AppColors.brandDark : AppColors.brand,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Raqamni tasdiqlash',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$formattedPhone raqamiga yuborilgan kodni kiriting',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.destructive.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.destructive.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.destructive,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.destructive,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _codeController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'SMS tasdiqlash kodi',
                    hintText: '123456',
                    prefixIcon: Icon(Icons.pin_outlined, size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 6) {
                      return 'Kamida 6 ta raqamli kod kiriting';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: _isVerifying ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Tasdiqlash'),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: (_isResending || _cooldownSeconds > 0)
                      ? null
                      : _resend,
                  child: Text(
                    _cooldownSeconds > 0
                        ? 'Kodni qayta yuborish (${_cooldownSeconds}s)'
                        : 'Kodni qayta yuborish',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
