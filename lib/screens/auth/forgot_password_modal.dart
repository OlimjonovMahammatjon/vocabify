import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../providers/auth_provider.dart';

/// Opens a clean bottom sheet for password recovery via Phone SMS OTP or Email.
Future<void> showForgotPasswordModal(
  BuildContext context, {
  String initialEmail = '',
  String initialPhone = '',
  bool startWithPhone = true,
  bool lockEmail = false,
  bool lockIdentifier = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ForgotPasswordSheet(
      initialEmail: initialEmail,
      initialPhone: initialPhone,
      startWithPhone: startWithPhone,
      lockIdentifier: lockEmail || lockIdentifier,
    ),
  );
}

class _ForgotPasswordSheet extends StatefulWidget {
  final String initialEmail;
  final String initialPhone;
  final bool startWithPhone;
  final bool lockIdentifier;

  const _ForgotPasswordSheet({
    required this.initialEmail,
    required this.initialPhone,
    required this.startWithPhone,
    required this.lockIdentifier,
  });

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _identifierFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  late bool _usePhone;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  final _tokenController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _codeSent = false;
  bool _isSending = false;
  bool _isResetting = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  late final AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    final hasPhone = widget.initialPhone.trim().isNotEmpty;
    final hasEmail = widget.initialEmail.trim().isNotEmpty;
    if (hasPhone && !hasEmail) {
      _usePhone = true;
    } else if (hasEmail && !hasPhone) {
      _usePhone = false;
    } else {
      _usePhone = widget.startWithPhone;
    }

    _phoneController = TextEditingController(text: widget.initialPhone.trim());
    _emailController = TextEditingController(text: widget.initialEmail.trim());
    _authProvider = context.read<AuthProvider>();
    _authProvider.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    // Only auto-dismiss when a deep link triggers recovery externally, not while
    // this modal itself is mid-flight verifying an OTP code.
    if (mounted && !_isResetting && _authProvider.isPasswordRecovery) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    _cooldownTimer?.cancel();
    _phoneController.dispose();
    _emailController.dispose();
    _tokenController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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

  Future<void> _sendReset() async {
    if (!_identifierFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    final error = _usePhone
        ? await _authProvider.sendPhonePasswordResetOtp(_phoneController.text)
        : await _authProvider.sendPasswordResetEmail(_emailController.text);

    if (!mounted) return;
    setState(() => _isSending = false);

    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    setState(() => _codeSent = true);
    _startCooldown();
  }

  Future<void> _verifyAndReset() async {
    if (!_resetFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isResetting = true;
      _errorMessage = null;
    });

    final error = _usePhone
        ? await _authProvider.verifyPhoneRecoveryAndResetPassword(
            phone: _phoneController.text,
            token: _tokenController.text,
            newPassword: _newPasswordController.text,
          )
        : await _authProvider.verifyRecoveryOtpAndResetPassword(
            email: _emailController.text,
            token: _tokenController.text,
            newPassword: _newPasswordController.text,
          );

    if (!mounted) return;
    setState(() => _isResetting = false);

    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Parol muvaffaqiyatli yangilandi!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _buildModeChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final activeBg = isDark ? AppColors.darkCard : Colors.white;
    final activeText = isDark ? Colors.white : AppColors.lightText;
    final inactiveText = isDark
        ? AppColors.darkTextMuted
        : AppColors.lightTextMuted;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? activeText : inactiveText),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? activeText : inactiveText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final sentTarget = _usePhone
        ? AppHelpers.formatPhoneDisplay(_phoneController.text)
        : _emailController.text.trim();

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
                      Icons.lock_reset_rounded,
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
                          'Parolni tiklash',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _codeSent
                              ? 'Tasdiqlash kodini kiriting va yangi parol o\'rnating'
                              : (_usePhone
                                    ? 'Telefon raqamingizga SMS kod yuboramiz'
                                    : 'Email manzilingizga tiklash xatini yuboramiz'),
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
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (!widget.lockIdentifier && !_codeSent) ...[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSecondary
                        : AppColors.lightSecondary,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      _buildModeChip(
                        label: 'Telefon',
                        icon: Icons.phone_outlined,
                        selected: _usePhone,
                        isDark: isDark,
                        onTap: () {
                          if (!_usePhone) {
                            setState(() {
                              _usePhone = true;
                              _errorMessage = null;
                            });
                          }
                        },
                      ),
                      _buildModeChip(
                        label: 'Email',
                        icon: Icons.email_outlined,
                        selected: !_usePhone,
                        isDark: isDark,
                        onTap: () {
                          if (_usePhone) {
                            setState(() {
                              _usePhone = false;
                              _errorMessage = null;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

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

              Form(
                key: _identifierFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_usePhone)
                      TextFormField(
                        controller: _phoneController,
                        readOnly: widget.lockIdentifier || _codeSent,
                        keyboardType: TextInputType.phone,
                        onChanged: (_) {
                          if (_errorMessage != null) {
                            setState(() => _errorMessage = null);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Telefon raqami',
                          hintText: '+998 90 123 45 67',
                          prefixIcon: const Icon(
                            Icons.phone_outlined,
                            size: 20,
                          ),
                          suffixIcon: _codeSent && !widget.lockIdentifier
                              ? IconButton(
                                  tooltip: 'Raqamni o\'zgartirish',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  onPressed: () => setState(() {
                                    _codeSent = false;
                                    _errorMessage = null;
                                  }),
                                )
                              : null,
                        ),
                        validator: (v) {
                          if (v == null || !AppHelpers.isValidPhone(v)) {
                            return 'To\'g\'ri raqam kiriting (+998901234567)';
                          }
                          return null;
                        },
                      )
                    else
                      TextFormField(
                        controller: _emailController,
                        readOnly: widget.lockIdentifier || _codeSent,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) {
                          if (_errorMessage != null) {
                            setState(() => _errorMessage = null);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'siz@example.com',
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            size: 20,
                          ),
                          suffixIcon: _codeSent && !widget.lockIdentifier
                              ? IconButton(
                                  tooltip: 'Emailni o\'zgartirish',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  onPressed: () => setState(() {
                                    _codeSent = false;
                                    _errorMessage = null;
                                  }),
                                )
                              : null,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email kiriting';
                          }
                          if (!v.contains('@')) {
                            return 'Yaroqli email kiriting';
                          }
                          return null;
                        },
                      ),
                    if (!_codeSent) ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isSending ? null : _sendReset,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _usePhone
                                    ? 'SMS kod yuborish'
                                    : 'Tiklash xatini yuborish',
                              ),
                      ),
                    ],
                  ],
                ),
              ),

              if (_codeSent) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _usePhone
                            ? Icons.sms_outlined
                            : Icons.mark_email_read_outlined,
                        color: AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _usePhone
                              ? '$sentTarget raqamiga 6 xonali SMS kod yuborildi. Kodni va yangi parolingizni kiriting.'
                              : '$sentTarget manziliga tiklash xati yuborildi. Emaildagi havolani bosing yoki kelgan kodni kiriting.',
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Form(
                  key: _resetFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _tokenController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: _usePhone
                              ? 'SMS tasdiqlash kodi'
                              : 'Tasdiqlash kodi (emaildan)',
                          hintText: '123456',
                          prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().length < 6) {
                            return 'Kamida 6 ta raqamli kod kiriting';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNew,
                        decoration: InputDecoration(
                          labelText: 'Yangi parol (kamida 8 belgi)',
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNew
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscureNew = !_obscureNew),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().length < 8) {
                            return 'Kamida 8 ta belgi kiriting';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Yangi parolni tasdiqlang',
                          hintText: '••••••••',
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null ||
                              v.trim() != _newPasswordController.text.trim()) {
                            return 'Parollar mos kelmadi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isResetting ? null : _verifyAndReset,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: _isResetting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Parolni yangilash'),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: (_isSending || _cooldownSeconds > 0)
                            ? null
                            : _sendReset,
                        child: Text(
                          _cooldownSeconds > 0
                              ? 'Qayta yuborish (${_cooldownSeconds}s)'
                              : (_usePhone
                                    ? 'SMS kodni qayta yuborish'
                                    : 'Xatni qayta yuborish'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
