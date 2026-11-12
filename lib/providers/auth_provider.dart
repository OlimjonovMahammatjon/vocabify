import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/supabase_service.dart';
import '../core/services/offline_queue_service.dart';
import '../core/services/cache_service.dart';
import '../core/utils/helpers.dart';
import '../models/profile_model.dart';

class AuthProvider extends ChangeNotifier {
  final Future<void> _coreInitialization;
  User? _user;
  ProfileModel? _profile;
  bool _isLoading = true;
  bool _isPasswordRecovery = false;
  bool _isDisposed = false;
  StreamSubscription<AuthState>? _authSubscription;
  int _authGeneration = 0;

  User? get user => _user;
  ProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isPasswordRecovery => _isPasswordRecovery;
  bool get isAuthenticated => _user != null;

  AuthProvider({Future<void>? coreInitialization})
    : _coreInitialization = coreInitialization ?? Future<void>.value() {
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      await _coreInitialization;
    } catch (error) {
      debugPrint('Auth initialization unavailable: $error');
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
      return;
    }
    if (_isDisposed) return;
    _user = SupabaseService.currentUser;
    CacheService.instance.activateUser(_user?.id);
    await OfflineQueueService.instance.activateUser(_user?.id);

    if (_user != null) {
      // Instant display from local cache
      final cached = await CacheService.instance.getCachedProfile();
      if (cached != null) {
        _profile = cached;
      }
      _isLoading = false;
      notifyListeners();
      loadProfile();
    } else {
      _isLoading = false;
      notifyListeners();
    }

    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      final generation = ++_authGeneration;
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _isPasswordRecovery = true;
      } else if (data.event == AuthChangeEvent.signedOut) {
        _isPasswordRecovery = false;
      }
      final session = data.session;
      _user = session?.user;
      CacheService.instance.activateUser(_user?.id);
      await OfflineQueueService.instance.activateUser(_user?.id);
      if (generation != _authGeneration) return;

      if (_user != null) {
        final cached = await CacheService.instance.getCachedProfile();
        if (generation != _authGeneration) return;
        _profile = cached;
        _isLoading = false;
        notifyListeners();
        loadProfile();
      } else {
        _profile = null;
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> loadProfile() async {
    final userId = _user?.id;
    if (userId == null) return;
    final generation = _authGeneration;
    try {
      final res = await SupabaseService.client
          .from('profiles')
          .select(ProfileModel.databaseColumns)
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (generation != _authGeneration || _user?.id != userId) return;
      if (res != null) {
        _profile = ProfileModel.fromJson(res);
        await CacheService.instance.cacheProfile(_profile!);
      }
    } catch (e) {
      if (generation != _authGeneration || _user?.id != userId) return;
      debugPrint('Error loading profile: $e');
      // If network fails, try to load from cache if not already loaded
      _profile ??= await CacheService.instance.getCachedProfile();
    } finally {
      if (generation == _authGeneration && _user?.id == userId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Maps Supabase and network errors to user-facing Uzbek messages.
  @visibleForTesting
  static String formatAuthError(Object error, {required String fallback}) {
    final raw = error is AuthException ? error.message : error.toString();
    final msg = raw.toLowerCase();

    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'Email yoki parol noto\'g\'ri';
    }
    if (msg.contains('phone logins are disabled') ||
        msg.contains('phone provider is disabled')) {
      return 'Telefon orqali kirish Supabase sozlamalarida yoqilmagan';
    }
    if (msg.contains('error sending confirmation sms') ||
        msg.contains('unable to send sms') ||
        msg.contains('sms provider') ||
        msg.contains('twilio')) {
      return 'SMS yuborib bo\'lmadi. Supabase SMS provayderi sozlamalarini tekshiring';
    }
    if (msg.contains('signups not allowed for otp') ||
        msg.contains('user not found')) {
      return 'Bu hisob ro\'yxatdan o\'tmagan';
    }
    if (msg.contains('phone_exists') ||
        msg.contains('phone number already registered')) {
      return 'Bu telefon raqami allaqachon ro\'yxatdan o\'tgan';
    }
    if (msg.contains('invalid phone')) {
      return 'To\'g\'ri telefon raqami kiriting (+998901234567)';
    }
    if (msg.contains('email not confirmed')) {
      return 'Email manzilingiz hali tasdiqlanmagan';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already been registered')) {
      return 'Bu email allaqachon ro\'yxatdan o\'tgan';
    }
    if (msg.contains('too many requests') || msg.contains('rate limit')) {
      return 'Juda ko\'p urinish bo\'ldi. Birozdan keyin qayta urinib ko\'ring';
    }
    if (msg.contains('weak password')) {
      return 'Parol juda oddiy. Kuchliroq parol kiriting';
    }
    if (msg.contains('same_password') ||
        msg.contains('different from the old password')) {
      return 'Yangi parol eski paroldan farqli bo\'lishi kerak';
    }
    if (msg.contains('otp_expired') ||
        msg.contains('token has expired') ||
        msg.contains('invalid otp')) {
      return 'Tasdiqlash kodi noto\'g\'ri yoki muddati tugagan';
    }
    if (msg.contains('invalid email') ||
        msg.contains('unable to validate email address')) {
      return 'Yaroqli email manzil kiriting';
    }
    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('clientexception') ||
        msg.contains('timeoutexception') ||
        msg.contains('network')) {
      return 'Internet aloqasini tekshiring';
    }

    if (error is AuthException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    return fallback;
  }

  Future<String?> signInWithPhone(String phone, String password) async {
    final normalized = AppHelpers.normalizePhone(phone);
    if (!AppHelpers.isValidPhone(normalized)) {
      return 'To\'g\'ri telefon raqami kiriting (masalan: +998901234567)';
    }
    try {
      final res = await SupabaseService.client.auth.signInWithPassword(
        phone: normalized,
        password: password.trim(),
      );

      if (res.user == null) {
        return 'Telefon raqami yoki parol noto\'g\'ri';
      }

      _user = res.user;
      CacheService.instance.activateUser(_user?.id);
      await OfflineQueueService.instance.activateUser(_user?.id);
      await loadProfile();
      return null;
    } catch (e) {
      final raw = e is AuthException
          ? e.message.toLowerCase()
          : e.toString().toLowerCase();
      if (raw.contains('invalid login credentials') ||
          raw.contains('invalid_credentials')) {
        return 'Telefon raqami yoki parol noto\'g\'ri';
      }
      return formatAuthError(
        e,
        fallback: 'Tizimga kirishda xatolik yuz berdi',
      );
    }
  }

  Future<({String? error, bool needsVerification})> signUpWithPhone(
    String phone,
    String password,
    String name,
  ) async {
    final normalized = AppHelpers.normalizePhone(phone);
    if (!AppHelpers.isValidPhone(normalized)) {
      return (
        error: 'To\'g\'ri telefon raqami kiriting (masalan: +998901234567)',
        needsVerification: false,
      );
    }
    try {
      final res = await SupabaseService.client.auth.signUp(
        phone: normalized,
        password: password.trim(),
        data: {
          'display_name': name.trim().isEmpty
              ? AppHelpers.formatPhoneDisplay(normalized)
              : name.trim(),
          'phone_number': normalized,
        },
      );

      if (res.session == null) {
        return (error: null, needsVerification: true);
      }

      _user = res.user;
      CacheService.instance.activateUser(_user?.id);
      await OfflineQueueService.instance.activateUser(_user?.id);
      if (_user != null) {
        await loadProfile();
      }
      return (error: null, needsVerification: false);
    } catch (e) {
      return (
        error: formatAuthError(
          e,
          fallback: 'Ro\'yxatdan o\'tishda xatolik yuz berdi',
        ),
        needsVerification: false,
      );
    }
  }

  Future<String?> verifyPhoneSignUpOtp({
    required String phone,
    required String token,
  }) async {
    final normalized = AppHelpers.normalizePhone(phone);
    final cleanToken = token.trim();
    if (cleanToken.length < 6) {
      return 'SMS orqali kelgan 6 xonali kodni kiriting';
    }
    try {
      final res = await SupabaseService.client.auth.verifyOTP(
        phone: normalized,
        token: cleanToken,
        type: OtpType.sms,
      );
      _user = res.user ?? SupabaseService.currentUser;
      CacheService.instance.activateUser(_user?.id);
      await OfflineQueueService.instance.activateUser(_user?.id);
      if (_user != null) {
        await loadProfile();
      }
      if (!_isDisposed) {
        notifyListeners();
      }
      return null;
    } catch (e) {
      return formatAuthError(
        e,
        fallback: 'SMS kodni tasdiqlashda xatolik yuz berdi',
      );
    }
  }

  Future<String?> resendPhoneSignUpOtp(String phone) async {
    final normalized = AppHelpers.normalizePhone(phone);
    if (!AppHelpers.isValidPhone(normalized)) {
      return 'To\'g\'ri telefon raqami kiriting';
    }
    try {
      await SupabaseService.client.auth.resend(
        type: OtpType.sms,
        phone: normalized,
      );
      return null;
    } catch (e) {
      return formatAuthError(
        e,
        fallback: 'SMS kodni qayta yuborishda xatolik yuz berdi',
      );
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      final res = await SupabaseService.client.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (res.user == null) {
        return 'Email yoki parol noto\'g\'ri';
      }

      _user = res.user;
      CacheService.instance.activateUser(_user?.id);
      await OfflineQueueService.instance.activateUser(_user?.id);
      await loadProfile();
      return null;
    } catch (e) {
      return formatAuthError(
        e,
        fallback: 'Tizimga kirishda xatolik yuz berdi',
      );
    }
  }

  Future<String?> signUp(String email, String password, String name) async {
    try {
      final res = await SupabaseService.client.auth.signUp(
        email: email.trim(),
        password: password.trim(),
        data: {
          'display_name': name.trim().isEmpty
              ? email.split('@')[0]
              : name.trim(),
        },
      );

      _user = res.user;
      CacheService.instance.activateUser(_user?.id);
      await OfflineQueueService.instance.activateUser(_user?.id);

      // Ensure profile exists or is created
      if (_user != null) {
        await loadProfile();
      }

      return null;
    } catch (e) {
      return formatAuthError(
        e,
        fallback: 'Ro\'yxatdan o\'tishda xatolik yuz berdi',
      );
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    final signingOutUserId = _user?.id;
    ++_authGeneration;
    try {
      await SupabaseService.client.auth.signOut();
    } finally {
      await CacheService.instance.clearUserCache(userId: signingOutUserId);
      _user = null;
      _profile = null;
      _isPasswordRecovery = false;
      CacheService.instance.activateUser(null);
      await OfflineQueueService.instance.activateUser(null);
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteAccount() async {
    _isLoading = true;
    notifyListeners();
    final deletingUserId = _user?.id;
    ++_authGeneration;
    try {
      if (deletingUserId != null) {
        await SupabaseService.client.rpc('delete_user_account');
      }
    } catch (e) {
      debugPrint('delete_user_account rpc error: $e');
      try {
        if (deletingUserId != null) {
          await SupabaseService.client
              .from('profiles')
              .delete()
              .eq('id', deletingUserId);
        }
      } catch (_) {}
    } finally {
      try {
        await SupabaseService.client.auth.signOut();
      } catch (_) {}
      await CacheService.instance.clearUserCache(userId: deletingUserId);
      _user = null;
      _profile = null;
      CacheService.instance.activateUser(null);
      await OfflineQueueService.instance.activateUser(null);
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> sendPhonePasswordResetOtp(String phone) async {
    final normalized = AppHelpers.normalizePhone(phone);
    if (!AppHelpers.isValidPhone(normalized)) {
      return 'To\'g\'ri telefon raqami kiriting (masalan: +998901234567)';
    }
    try {
      await SupabaseService.client.auth.signInWithOtp(
        phone: normalized,
        shouldCreateUser: false,
      );
      return null;
    } catch (e) {
      return formatAuthError(
        e,
        fallback: 'SMS kodni yuborishda xatolik yuz berdi',
      );
    }
  }

  Future<String?> verifyPhoneRecoveryAndResetPassword({
    required String phone,
    required String token,
    required String newPassword,
  }) async {
    final normalized = AppHelpers.normalizePhone(phone);
    final cleanToken = token.trim();
    final cleanPassword = newPassword.trim();
    if (!AppHelpers.isValidPhone(normalized)) {
      return 'To\'g\'ri telefon raqami kiriting';
    }
    if (cleanToken.length < 6) {
      return 'SMS orqali kelgan tasdiqlash kodini to\'liq kiriting';
    }
    if (cleanPassword.length < 8) {
      return 'Yangi parol kamida 8 ta belgidan iborat bo\'lishi kerak';
    }

    bool otpVerified = false;
    _isPasswordRecovery = true;
    try {
      await SupabaseService.client.auth.verifyOTP(
        phone: normalized,
        token: cleanToken,
        type: OtpType.sms,
      );
      otpVerified = true;
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: cleanPassword),
      );
      _isPasswordRecovery = false;
      if (!_isDisposed) {
        notifyListeners();
      }
      return null;
    } catch (e) {
      if (!otpVerified) {
        _isPasswordRecovery = false;
      }
      return formatAuthError(
        e,
        fallback: 'Parolni tiklashda xatolik yuz berdi',
      );
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return 'Yaroqli email manzil kiriting';
    }
    try {
      await SupabaseService.client.auth.resetPasswordForEmail(
        cleanEmail,
        redirectTo: 'vocabify://reset-callback',
      );
      return null;
    } catch (e) {
      return formatAuthError(
        e,
        fallback: 'Parolni tiklash xatini yuborishda xatolik yuz berdi',
      );
    }
  }

  Future<String?> verifyRecoveryOtpAndResetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim();
    final cleanToken = token.trim();
    final cleanPassword = newPassword.trim();
    if (cleanToken.length < 6) {
      return 'Emailga kelgan tasdiqlash kodini to\'liq kiriting';
    }
    if (cleanPassword.length < 8) {
      return 'Yangi parol kamida 8 ta belgidan iborat bo\'lishi kerak';
    }

    bool otpVerified = false;
    _isPasswordRecovery = true;
    try {
      await SupabaseService.client.auth.verifyOTP(
        email: cleanEmail,
        token: cleanToken,
        type: OtpType.recovery,
      );
      otpVerified = true;
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: cleanPassword),
      );
      _isPasswordRecovery = false;
      if (!_isDisposed) {
        notifyListeners();
      }
      return null;
    } catch (e) {
      if (!otpVerified) {
        _isPasswordRecovery = false;
      }
      return formatAuthError(
        e,
        fallback: 'Parolni tiklashda xatolik yuz berdi',
      );
    }
  }

  Future<String?> completePasswordRecovery(String newPassword) async {
    final cleanPassword = newPassword.trim();
    if (cleanPassword.length < 8) {
      return 'Yangi parol kamida 8 ta belgidan iborat bo\'lishi kerak';
    }
    try {
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: cleanPassword),
      );
      _isPasswordRecovery = false;
      if (!_isDisposed) {
        notifyListeners();
      }
      return null;
    } catch (e) {
      return formatAuthError(
        e,
        fallback: 'Yangi parolni saqlashda xatolik yuz berdi',
      );
    }
  }

  Future<void> cancelPasswordRecovery() async {
    _isPasswordRecovery = false;
    await signOut();
  }

  Future<String?> updateUsername(String newUsername) async {
    final clean = newUsername.trim();
    if (clean.length < 2) {
      return 'Username kamida 2 ta belgidan iborat bo\'lishi kerak';
    }
    if (_user == null) {
      return 'Tizimga kirilmagan';
    }

    final currentGoal = _profile?.dailyGoal ?? 20;
    final ok = await updateProfile(displayName: clean, dailyGoal: currentGoal);
    if (!ok) {
      return 'Username ni saqlashda xatolik yuz berdi';
    }

    try {
      final res = await SupabaseService.client.auth.updateUser(
        UserAttributes(data: {'display_name': clean}),
      );
      if (res.user != null) {
        _user = res.user;
        if (!_isDisposed) {
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Auth metadata display_name sync skipped: $e');
    }
    return null;
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _user?.email;
    final phone = _user?.phone;
    final hasEmail = email != null && email.isNotEmpty;
    final hasPhone = phone != null && phone.isNotEmpty;
    if (!hasEmail && !hasPhone) {
      return 'Foydalanuvchi hisob ma\'lumotlari topilmadi';
    }
    if (newPassword.trim().length < 8) {
      return 'Yangi parol kamida 8 ta belgidan iborat bo\'lishi kerak';
    }
    if (currentPassword.trim() == newPassword.trim()) {
      return 'Yangi parol joriy paroldan farqli bo\'lishi kerak';
    }

    try {
      if (hasEmail) {
        await SupabaseService.client.auth.signInWithPassword(
          email: email,
          password: currentPassword.trim(),
        );
      } else {
        await SupabaseService.client.auth.signInWithPassword(
          phone: phone!,
          password: currentPassword.trim(),
        );
      }
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: newPassword.trim()),
      );
      return null;
    } catch (e) {
      final raw = e is AuthException
          ? e.message.toLowerCase()
          : e.toString().toLowerCase();
      if (raw.contains('invalid login credentials') ||
          raw.contains('invalid_credentials')) {
        return 'Joriy parol noto\'g\'ri';
      }
      return formatAuthError(
        e,
        fallback: 'Parolni o\'zgartirishda xatolik yuz berdi',
      );
    }
  }

  Future<bool> updateProfile({
    required String displayName,
    required int dailyGoal,
  }) async {
    if (_user == null) return false;

    // Optimistic local update
    if (_profile != null) {
      _profile = _profile!.copyWith(
        displayName: displayName,
        dailyGoal: dailyGoal,
      );
      await CacheService.instance.cacheProfile(_profile!);
      notifyListeners();
    }

    try {
      await OfflineQueueService.instance.queuedWrite(
        QueuedOp(
          kind: OpKind.update,
          table: 'profiles',
          match: {'id': _user!.id},
          values: {
            'display_name': displayName,
            'daily_goal': dailyGoal,
            'updated_at': DateTime.now().toIso8601String(),
          },
        ),
      );
      OfflineQueueService.instance.flushQueue();
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  void updateLocalProfile(ProfileModel updatedProfile) {
    if (_profile?.id == updatedProfile.id || _user?.id == updatedProfile.id) {
      _profile = updatedProfile;
      CacheService.instance.cacheProfile(updatedProfile);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _authSubscription?.cancel();
    super.dispose();
  }
}
