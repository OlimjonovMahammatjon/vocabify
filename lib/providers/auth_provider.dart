import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/supabase_service.dart';
import '../core/services/offline_queue_service.dart';
import '../core/services/cache_service.dart';
import '../models/profile_model.dart';

class AuthProvider extends ChangeNotifier {
  final Future<void> _coreInitialization;
  User? _user;
  ProfileModel? _profile;
  bool _isLoading = true;
  bool _isDisposed = false;
  StreamSubscription<AuthState>? _authSubscription;
  int _authGeneration = 0;

  User? get user => _user;
  ProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
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

  Future<String?> signIn(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final res = await SupabaseService.client.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );

      _user = res.user;
      CacheService.instance.activateUser(_user?.id);
      await OfflineQueueService.instance.activateUser(_user?.id);
      await loadProfile();
      return null;
    } on AuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Tizimga kirishda xatolik yuz berdi';
    }
  }

  Future<String?> signUp(String email, String password, String name) async {
    try {
      _isLoading = true;
      notifyListeners();

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
    } on AuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Ro\'yxatdan o\'tishda xatolik yuz berdi';
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
