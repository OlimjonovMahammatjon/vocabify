import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../providers/auth_provider.dart';
import '../main_navigation_screen.dart';
import 'forgot_password_modal.dart';
import 'phone_otp_modal.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  final _signInPhoneController = TextEditingController();
  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();

  final _signUpNameController = TextEditingController();
  final _signUpPhoneController = TextEditingController();
  final _signUpEmailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();

  bool _usePhoneAuth = true;
  bool _obscureSignInPass = true;
  bool _obscureSignUpPass = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging && _errorMessage != null) {
        setState(() => _errorMessage = null);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signInPhoneController.dispose();
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _signUpNameController.dispose();
    _signUpPhoneController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _submitAuth({
    required GlobalKey<FormState> formKey,
    required Future<String?> Function() action,
    String? successMessage,
  }) async {
    if (!formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final error = await action();

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error != null) {
      setState(() => _errorMessage = error);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.destructive,
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    if (successMessage != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
  }

  void _showErrorFeedback(String error) {
    setState(() => _errorMessage = error);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _navigateToHome({String? successMessage}) {
    if (successMessage != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
  }

  Future<void> _handleSignIn() {
    final auth = context.read<AuthProvider>();
    return _submitAuth(
      formKey: _signInFormKey,
      action: () => _usePhoneAuth
          ? auth.signInWithPhone(
              _signInPhoneController.text,
              _signInPasswordController.text,
            )
          : auth.signIn(
              _signInEmailController.text,
              _signInPasswordController.text,
            ),
    );
  }

  Future<void> _handleSignUp() async {
    final auth = context.read<AuthProvider>();
    if (!_usePhoneAuth) {
      await _submitAuth(
        formKey: _signUpFormKey,
        action: () => auth.signUp(
          _signUpEmailController.text,
          _signUpPasswordController.text,
          _signUpNameController.text,
        ),
        successMessage: 'Xush kelibsiz! 🎉',
      );
      return;
    }

    if (!_signUpFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = await auth.signUpWithPhone(
      _signUpPhoneController.text,
      _signUpPasswordController.text,
      _signUpNameController.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.error != null) {
      _showErrorFeedback(result.error!);
      return;
    }

    if (result.needsVerification) {
      final verified = await showPhoneOtpVerifyModal(
        context,
        phone: AppHelpers.normalizePhone(_signUpPhoneController.text),
      );
      if (!mounted || !verified) return;
    }

    _navigateToHome(successMessage: 'Xush kelibsiz! 🎉');
  }

  Widget _buildContactMethodSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          _buildMethodPill(
            label: 'Telefon',
            icon: Icons.phone_outlined,
            selected: _usePhoneAuth,
            isDark: isDark,
            onTap: () {
              if (!_usePhoneAuth) {
                setState(() {
                  _usePhoneAuth = true;
                  _errorMessage = null;
                });
              }
            },
          ),
          _buildMethodPill(
            label: 'Email',
            icon: Icons.email_outlined,
            selected: !_usePhoneAuth,
            isDark: isDark,
            onTap: () {
              if (_usePhoneAuth) {
                setState(() {
                  _usePhoneAuth = false;
                  _errorMessage = null;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMethodPill({
    required String label,
    required IconData icon,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final activeText = isDark ? Colors.white : AppColors.lightText;
    final mutedText = isDark
        ? AppColors.darkTextMuted
        : AppColors.lightTextMuted;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? AppColors.darkCard : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: selected ? activeText : mutedText),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? activeText : mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdentifierField({
    required TextEditingController phoneController,
    required TextEditingController emailController,
  }) {
    if (_usePhoneAuth) {
      return TextFormField(
        key: ValueKey('phone_${phoneController.hashCode}'),
        controller: phoneController,
        keyboardType: TextInputType.phone,
        onChanged: (_) => _clearError(),
        decoration: const InputDecoration(
          labelText: 'Telefon raqami',
          hintText: '+998 90 123 45 67',
          prefixIcon: Icon(Icons.phone_outlined, size: 20),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) {
            return 'Telefon raqamini kiriting';
          }
          if (!AppHelpers.isValidPhone(v)) {
            return 'To\'g\'ri raqam kiriting (+998901234567)';
          }
          return null;
        },
      );
    }

    return TextFormField(
      key: ValueKey('email_${emailController.hashCode}'),
      controller: emailController,
      keyboardType: TextInputType.emailAddress,
      onChanged: (_) => _clearError(),
      decoration: const InputDecoration(
        labelText: 'Email',
        hintText: 'siz@example.com',
        prefixIcon: Icon(Icons.email_outlined, size: 20),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Hero Image & Title
                  Image.asset(
                    'assets/images/hero-study.png',
                    height: 120,
                    cacheWidth: 384,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.menu_book_rounded,
                      size: 80,
                      color: AppColors.brand,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      text: 'Vocab',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                      children: const [
                        TextSpan(
                          text: 'ify',
                          style: TextStyle(color: AppColors.brandDark),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ingliz tili so\'zlarini aqlli takrorlash bilan yodlang',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Form Container
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.3 : 0.06,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Tab Selector
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSecondary
                                : AppColors.lightSecondary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: isDark ? AppColors.darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            labelColor: isDark
                                ? Colors.white
                                : AppColors.lightText,
                            unselectedLabelColor: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            tabs: const [
                              Tab(text: 'Kirish'),
                              Tab(text: 'Ro\'yxatdan o\'tish'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildContactMethodSelector(isDark),
                        const SizedBox(height: 14),

                        if (_errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.destructive.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.destructive.withValues(
                                  alpha: 0.4,
                                ),
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
                        ] else
                          const SizedBox(height: 4),

                        // Form Tab Views
                        SizedBox(
                          height: 316,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // Sign In Form
                              Form(
                                key: _signInFormKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: _signInEmailController,
                                      keyboardType: TextInputType.emailAddress,
                                      onChanged: (_) => _clearError(),
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                        hintText: 'siz@example.com',
                                        prefixIcon: Icon(
                                          Icons.email_outlined,
                                          size: 20,
                                        ),
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
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _signInPasswordController,
                                      obscureText: _obscureSignInPass,
                                      onChanged: (_) => _clearError(),
                                      decoration: InputDecoration(
                                        labelText: 'Parol',
                                        hintText: '••••••••',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                          size: 20,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureSignInPass
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            size: 20,
                                          ),
                                          onPressed: () => setState(
                                            () => _obscureSignInPass =
                                                !_obscureSignInPass,
                                          ),
                                        ),
                                      ),
                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return 'Parol kiriting';
                                        }
                                        if (v.length < 8) {
                                          return 'Kamida 8 ta belgi';
                                        }
                                        return null;
                                      },
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _isSubmitting
                                            ? null
                                            : () => showForgotPasswordModal(
                                                context,
                                                initialEmail:
                                                    _signInEmailController.text,
                                              ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 6,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          'Parolni unutdingizmi?',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? AppColors.brandDark
                                                : AppColors.brand,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    ElevatedButton(
                                      onPressed: _isSubmitting
                                          ? null
                                          : _handleSignIn,
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                      ),
                                      child: _isSubmitting
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('Kirish'),
                                    ),
                                  ],
                                ),
                              ),

                              // Sign Up Form
                              Form(
                                key: _signUpFormKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: _signUpNameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Ismingiz',
                                        hintText: 'Aziz',
                                        prefixIcon: Icon(
                                          Icons.person_outline,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _signUpEmailController,
                                      keyboardType: TextInputType.emailAddress,
                                      onChanged: (_) => _clearError(),
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                        hintText: 'siz@example.com',
                                        prefixIcon: Icon(
                                          Icons.email_outlined,
                                          size: 20,
                                        ),
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
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _signUpPasswordController,
                                      obscureText: _obscureSignUpPass,
                                      onChanged: (_) => _clearError(),
                                      decoration: InputDecoration(
                                        labelText: 'Parol (kamida 8 belgi)',
                                        hintText: '••••••••',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                          size: 20,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureSignUpPass
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            size: 20,
                                          ),
                                          onPressed: () => setState(
                                            () => _obscureSignUpPass =
                                                !_obscureSignUpPass,
                                          ),
                                        ),
                                      ),
                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return 'Parol kiriting';
                                        }
                                        if (v.length < 8) {
                                          return 'Kamida 8 ta belgi';
                                        }
                                        return null;
                                      },
                                    ),
                                    const Spacer(),
                                    ElevatedButton(
                                      onPressed: _isSubmitting
                                          ? null
                                          : _handleSignUp,
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                      ),
                                      child: _isSubmitting
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.auto_awesome_rounded,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text('Boshlash'),
                                              ],
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
