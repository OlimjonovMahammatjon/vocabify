import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vocabify_app/main.dart';
import 'package:vocabify_app/providers/auth_provider.dart';

class _FakeAuthProvider extends AuthProvider {
  _FakeAuthProvider()
    : super(
        coreInitialization: Future<void>.error(StateError('skip supabase')),
      );

  @override
  Future<String?> signIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return AuthProvider.formatAuthError(
      const AuthException('Invalid login credentials'),
      fallback: 'Tizimga kirishda xatolik yuz berdi',
    );
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
}
