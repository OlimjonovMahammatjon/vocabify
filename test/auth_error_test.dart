import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vocabify_app/main.dart';
import 'package:vocabify_app/models/profile_model.dart';
import 'package:vocabify_app/providers/auth_provider.dart';
import 'package:vocabify_app/providers/cards_provider.dart';
import 'package:vocabify_app/providers/decks_provider.dart';
import 'package:vocabify_app/providers/theme_provider.dart';
import 'package:vocabify_app/screens/auth/reset_password_screen.dart';
import 'package:vocabify_app/screens/profile/profile_screen.dart';

class _FakeAuthProvider extends AuthProvider {
  bool fakeRecovery = false;
  bool fakeAuthenticated = false;
  String? lastUpdatedUsername;
  String? lastResetEmail;
  String? lastCompletedRecoveryPassword;

  _FakeAuthProvider({
    this.fakeRecovery = false,
    this.fakeAuthenticated = false,
  }) : super(
         coreInitialization: Future<void>.error(StateError('skip supabase')),
       );

  @override
  bool get isPasswordRecovery => fakeRecovery;

  @override
  bool get isAuthenticated => fakeAuthenticated || fakeRecovery;

  @override
  ProfileModel? get profile => fakeAuthenticated
      ? ProfileModel(id: 'u1', displayName: 'Azizbek', dailyGoal: 25)
      : null;

  @override
  Future<String?> signIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return AuthProvider.formatAuthError(
      const AuthException('Invalid login credentials'),
      fallback: 'Tizimga kirishda xatolik yuz berdi',
    );
  }

  @override
  Future<String?> sendPasswordResetEmail(String email) async {
    lastResetEmail = email.trim();
    return null;
  }

  @override
  Future<String?> completePasswordRecovery(String newPassword) async {
    lastCompletedRecoveryPassword = newPassword.trim();
    fakeRecovery = false;
    notifyListeners();
    return null;
  }

  @override
  Future<String?> updateUsername(String newUsername) async {
    lastUpdatedUsername = newUsername.trim();
    return null;
  }

  @override
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword.trim() != 'oldpass123') {
      return 'Joriy parol noto\'g\'ri';
    }
    return null;
  }
}

void main() {
  test('formatAuthError translates common auth errors to Uzbek', () {
    expect(
      AuthProvider.formatAuthError(
        const AuthException('Invalid login credentials'),
        fallback: 'fallback',
      ),
      'Email yoki parol noto\'g\'ri',
    );
    expect(
      AuthProvider.formatAuthError(
        const AuthException('User already registered'),
        fallback: 'fallback',
      ),
      'Bu email allaqachon ro\'yxatdan o\'tgan',
    );
    expect(
      AuthProvider.formatAuthError(
        const AuthException('Email not confirmed'),
        fallback: 'fallback',
      ),
      'Email manzilingiz hali tasdiqlanmagan',
    );
    expect(
      AuthProvider.formatAuthError(
        const AuthException('New password should be different from the old password'),
        fallback: 'fallback',
      ),
      'Yangi parol eski paroldan farqli bo\'lishi kerak',
    );
    expect(
      AuthProvider.formatAuthError(
        const AuthException('Token has expired or is invalid'),
        fallback: 'fallback',
      ),
      'Tasdiqlash kodi noto\'g\'ri yoki muddati tugagan',
    );
  });

  test('signIn failure does not flip AuthProvider.isLoading to true', () async {
    final provider = AuthProvider(
      coreInitialization: Future<void>.error(StateError('no supabase')),
    );
    await Future<void>.delayed(Duration.zero);
    expect(provider.isLoading, isFalse);

    bool sawLoading = false;
    provider.addListener(() {
      if (provider.isLoading) sawLoading = true;
    });

    final result = await provider.signIn('user@example.com', 'wrongpass');
    expect(result, isNotNull);
    expect(sawLoading, isFalse);
    expect(provider.isLoading, isFalse);
    provider.dispose();
  });

  testWidgets(
    'AuthGate keeps AuthScreen mounted and shows error on wrong credentials',
    (tester) async {
      final fakeAuth = _FakeAuthProvider();
      await tester.pump();

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: fakeAuth,
          child: const MaterialApp(home: AuthGate()),
        ),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'wrong@example.com');
      await tester.enterText(fields.at(1), 'wrongpass123');
      final loginButton = find.widgetWithText(ElevatedButton, 'Kirish');
      await tester.ensureVisible(loginButton);
      await tester.pumpAndSettle();
      await tester.tap(loginButton);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // Error message is displayed and user's typed email is preserved.
      expect(find.text('Email yoki parol noto\'g\'ri'), findsWidgets);
      expect(find.text('wrong@example.com'), findsOneWidget);

      // Editing email clears the inline error banner.
      await tester.enterText(fields.at(0), 'retry@example.com');
      await tester.pump();
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    },
  );

  testWidgets(
    'AuthScreen opens Forgot Password modal pre-filled and advances to step 2',
    (tester) async {
      final fakeAuth = _FakeAuthProvider();
      await tester.pump();

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: fakeAuth,
          child: const MaterialApp(home: AuthGate()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'user@vocabify.uz');
      await tester.tap(find.text('Parolni unutdingizmi?'));
      await tester.pumpAndSettle();

      expect(find.text('Parolni tiklash'), findsOneWidget);
      expect(find.text('user@vocabify.uz'), findsWidgets);

      await tester.tap(find.text('Tiklash xatini yuborish'));
      await tester.pumpAndSettle();

      expect(fakeAuth.lastResetEmail, 'user@vocabify.uz');
      expect(find.text('Tasdiqlash kodi (emaildan)'), findsOneWidget);
      expect(find.text('Parolni yangilash'), findsOneWidget);
    },
  );

  testWidgets(
    'AuthGate routes to ResetPasswordScreen during password recovery',
    (tester) async {
      final fakeAuth = _FakeAuthProvider(fakeRecovery: true);
      await tester.pump();

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: fakeAuth,
          child: const MaterialApp(home: AuthGate()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.text('Yangi parol o\'rnatish'), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'newpass123');
      await tester.enterText(fields.at(1), 'newpass123');
      await tester.tap(find.text('Parolni saqlash'));
      await tester.pumpAndSettle();

      expect(fakeAuth.lastCompletedRecoveryPassword, 'newpass123');
    },
  );

  testWidgets(
    'ProfileScreen supports changing username and password cleanly',
    (tester) async {
      final fakeAuth = _FakeAuthProvider(fakeAuthenticated: true);
      await tester.pump();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: fakeAuth),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => DecksProvider()),
            ChangeNotifierProvider(create: (_) => CardsProvider()),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Username o\'zgartirish'), findsOneWidget);
      expect(find.text('Parolni o\'zgartirish'), findsOneWidget);

      await tester.tap(find.text('Username o\'zgartirish'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).last, 'Sardorbek');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Saqlash').last);
      await tester.pumpAndSettle();

      expect(fakeAuth.lastUpdatedUsername, 'Sardorbek');

      await tester.tap(find.text('Parolni o\'zgartirish'));
      await tester.pumpAndSettle();

      final passFields = find.byType(TextFormField);
      // Last 3 TextFormFields belong to the change password modal sheet.
      final count = passFields.evaluate().length;
      await tester.enterText(passFields.at(count - 3), 'wrongold');
      await tester.enterText(passFields.at(count - 2), 'newpass123');
      await tester.enterText(passFields.at(count - 1), 'newpass123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Parolni yangilash'));
      await tester.pumpAndSettle();

      expect(find.text('Joriy parol noto\'g\'ri'), findsOneWidget);
    },
  );
}
