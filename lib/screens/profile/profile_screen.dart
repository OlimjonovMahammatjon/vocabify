import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/widget_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/decks_provider.dart';
import '../../providers/cards_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/study_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/ai_settings_dialog.dart';
import '../auth/auth_screen.dart';
import '../auth/forgot_password_modal.dart';
import '../decks/ai_scan_screen.dart';
import 'account_security_sheets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _goalController = TextEditingController();
  late final AuthProvider _authProvider;
  String? _loadedProfileId;
  bool _isSaving = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _authProvider = context.read<AuthProvider>();
    _authProvider.addListener(_syncProfileControllers);
    _syncProfileControllers();
  }

  void _syncProfileControllers() {
    final profile = _authProvider.profile;
    if (profile == null || profile.id == _loadedProfileId || _isSaving) return;
    _loadedProfileId = profile.id;
    _goalController.text = profile.dailyGoal.toString();
  }

  @override
  void dispose() {
    _authProvider.removeListener(_syncProfileControllers);
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final goal = int.tryParse(_goalController.text.trim()) ?? 20;
    final auth = context.read<AuthProvider>();
    final currentName =
        auth.profile?.displayName ??
        auth.user?.userMetadata?['display_name']?.toString() ??
        '';

    setState(() => _isSaving = true);
    final success = await auth.updateProfile(
      displayName: currentName,
      dailyGoal: goal,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Sozlamalar saqlandi ✨' : 'Xatolik yuz berdi',
          ),
          backgroundColor: success ? AppColors.success : AppColors.destructive,
        ),
      );
    }
  }

  Future<void> _copyUserId(String userId) async {
    await Clipboard.setData(ClipboardData(text: userId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Foydalanuvchi ID nusxalandi'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleForceSync() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => _isSyncing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await Future.wait([
        context.read<AuthProvider>().loadProfile(),
        context.read<DecksProvider>().loadDecks(user.id, force: true),
        context.read<CardsProvider>().loadAllCards(user.id, force: true),
        context.read<StatsProvider>().loadStats(user.id, force: true),
      ]);

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Barcha ma\'lumotlar server bilan sinxronlandi va keshlandi! ✅',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Sinxronlashda xatolik: $e'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _pickReminderTime(BuildContext context) async {
    final notifService = NotificationService.instance;
    final currentTime = notifService.reminderTime;

    final picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
      helpText: 'KUNLIK ESLATMA VAQTINI TANLANG',
      confirmText: 'SAQLASH',
      cancelText: 'BEKOR QILISH',
    );

    if (picked != null) {
      await notifService.scheduleDailyReminder(
        hour: picked.hour,
        minute: picked.minute,
      );
      if (context.mounted) {
        final formattedTime =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Eslatma har kuni $formattedTime ga belgilandi! ⏰'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tizimdan chiqish'),
        content: const Text('Haqiqatan ham hisobingizdan chiqmoqchimisiz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              context.read<DecksProvider>().clear();
              context.read<CardsProvider>().clear();
              context.read<StatsProvider>().clear();
              context.read<StudyProvider>().clear();
              context.read<QuizProvider>().clear();
              await context.read<AuthProvider>().signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            child: const Text('Chiqish'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.destructive, size: 26),
            SizedBox(width: 8),
            Text('Hisobni o\'chirish'),
          ],
        ),
        content: const Text(
          'Diqqat! Hisobingiz, barcha to\'plamlaringiz, so\'zlaringiz va statistikalaringiz butunlay o\'chiriladi.\n\nUshbu amalni ortga qaytarib bo\'lmaydi. Haqiqatan ham hisobingizni o\'chirmoqchimisiz?',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              context.read<DecksProvider>().clear();
              context.read<CardsProvider>().clear();
              context.read<StatsProvider>().clear();
              context.read<StudyProvider>().clear();
              context.read<QuizProvider>().clear();
              await context.read<AuthProvider>().deleteAccount();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Hisobingiz va ma\'lumotlaringiz butunlay o\'chirildi.'),
                    backgroundColor: AppColors.destructive,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.destructive,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ha, hisobimni o\'chirish'),
          ),
        ],
      ),
    );
  }

  void _showWidgetGuideDialog(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brandDark.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.widgets_rounded,
                    color: AppColors.brandDark,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Bosh ekran vidjeti (Widget)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF334155), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '📚 Vocabify • Kun so\'zi',
                        style: TextStyle(
                          color: Color(0xFFA5B4FC),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A244D),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '🔥 Kunlik streak',
                          style: TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Resilience  /rɪˈzɪl.jəns/',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Matonat, qiyinchiliklarga chidamlilik',
                    style: TextStyle(
                      color: Color(0xFFE0E7FF),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '⏰ Bugungi takrorlash holati',
                        style: TextStyle(color: Color(0xFF93C5FD), fontSize: 11),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.brandDark,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'O\'rganish ▶',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Vidjetni qanday o\'rnatish mumkin?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '1. Telefoningiz asosiy ekranida bo\'sh joyni bosib turing.\n'
              '2. "Vidjetlar" (Widgets) bo\'limiga kiring.\n'
              '3. "Vocabify" vidjetini topib, bosh ekranga joylashtiring.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                final cards = context.read<CardsProvider>().allCards;
                await WidgetService.syncFromCards(cards);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vidjet ma\'lumotlari muvaffaqiyatli yangilandi! 📱'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Vidjetni hozir yangilash'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final decksProv = context.watch<DecksProvider>();
    final cardsProv = context.watch<CardsProvider>();
    final profile = auth.profile;
    final user = auth.user;

    final metaName = user?.userMetadata?['display_name']?.toString().trim() ?? '';
    final profileName = profile?.displayName?.trim() ?? '';
    final displayName = profileName.isNotEmpty
        ? profileName
        : (metaName.isNotEmpty ? metaName : 'Foydalanuvchi');
    final hasCustomName = profileName.isNotEmpty || metaName.isNotEmpty;

    final initialChar =
        (hasCustomName
                ? displayName[0]
                : (user?.email?.isNotEmpty == true ? user!.email![0] : '?'))
            .toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Profil & Sozlamalar')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Avatar Banner Card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF152238) : AppColors.brand,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.transparent,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initialChar,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  if (user != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Foydalanuvchi ID',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .72),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                SelectableText(
                                  user.id,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'ID ni nusxalash',
                            onPressed: () => _copyUserId(user.id),
                            icon: const Icon(
                              Icons.copy_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Account & Security Card (Username & Password Change)
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => showChangeUsernameSheet(
                      context,
                      currentUsername: hasCustomName ? displayName : '',
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                                  (isDark
                                          ? AppColors.brandDark
                                          : AppColors.brand)
                                      .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.person_outline_rounded,
                              color: isDark
                                  ? AppColors.brandDark
                                  : AppColors.brand,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Username o\'zgartirish',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkText
                                        : AppColors.lightText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hasCustomName
                                      ? displayName
                                      : 'Username belgilanmagan',
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
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.lightTextMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  InkWell(
                    onTap: () => showChangePasswordSheet(
                      context,
                      onForgotPassword: () => showForgotPasswordModal(
                        context,
                        initialEmail: user?.email ?? '',
                        lockEmail: (user?.email ?? '').isNotEmpty,
                      ),
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.lock_outline_rounded,
                              color: AppColors.accent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Parolni o\'zgartirish',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkText
                                        : AppColors.lightText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Hisob xavfsizligi uchun parolni yangilang',
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
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.lightTextMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Daily Goal Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Kunlik maqsad',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _goalController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Kunlik maqsad (so\'zlar soni)',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Saqlash'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Offline Cache & Data Status Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.offline_pin_rounded,
                          color: AppColors.success,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Offline Kesh & Ma\'lumotlar',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Avtonom rejimda ishlash uchun saqlangan',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSecondary
                          : AppColors.lightSecondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildCacheStat(
                          'To\'plamlar',
                          '${decksProv.decks.length} ta',
                          isDark,
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                        _buildCacheStat(
                          'So\'zlar',
                          '${cardsProv.allCards.length} ta',
                          isDark,
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                        _buildCacheStat(
                          'Kesh holati',
                          'Faol',
                          isDark,
                          valueColor: AppColors.success,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSyncing ? null : _handleForceSync,
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(
                        _isSyncing
                            ? 'Sinxronlanmoqda...'
                            : 'Server bilan sinxronlash',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Notification / Daily Reminder Card
            ValueListenableBuilder<bool>(
              valueListenable: NotificationService.instance.enabledNotifier,
              builder: (context, isNotifEnabled, _) {
                return ValueListenableBuilder<TimeOfDay>(
                  valueListenable: NotificationService.instance.timeNotifier,
                  builder: (context, notifTime, _) {
                    final formattedTime =
                        '${notifTime.hour.toString().padLeft(2, '0')}:${notifTime.minute.toString().padLeft(2, '0')}';

                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      (isNotifEnabled
                                              ? const Color(0xFFF59E0B)
                                              : Colors.grey)
                                          .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.notifications_active_rounded,
                                  color: isNotifEnabled
                                      ? const Color(0xFFF59E0B)
                                      : Colors.grey,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'So\'z yodlash eslatmalari',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isNotifEnabled
                                          ? 'Har kuni soat $formattedTime da eslatma keladi'
                                          : 'Bildirishnomalar o\'chirilgan',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppColors.darkTextMuted
                                            : AppColors.lightTextMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: isNotifEnabled,
                                activeTrackColor: AppColors.brand,
                                onChanged: (val) async {
                                  if (val) {
                                    await NotificationService.instance
                                        .scheduleDailyReminder(
                                          hour: notifTime.hour,
                                          minute: notifTime.minute,
                                        );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Eslatmalar yoqildi! ($formattedTime) 🔔',
                                          ),
                                          backgroundColor: AppColors.success,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } else {
                                    await NotificationService.instance
                                        .disableReminder();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Eslatmalar o\'chirildi 🔕',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),

                          if (isNotifEnabled) ...[
                            const SizedBox(height: 14),
                            InkWell(
                              onTap: () => _pickReminderTime(context),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkSecondary
                                      : AppColors.lightSecondary,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: (isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.schedule_rounded,
                                          size: 20,
                                          color: AppColors.brandDark,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Eslatma soati',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? AppColors.darkText
                                                : AppColors.lightText,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.brandDark
                                            : AppColors.brand,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            formattedTime,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.edit_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                onPressed: () async {
                                  await NotificationService.instance
                                      .showTestNotification();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Sinov eslatmasi yuborildi! Yuqori paneldan tekshiring 📲',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.send_rounded, size: 16),
                                label: const Text('Sinov eslatmasini yuborish'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 14),

            // Home Screen Widget Card
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: InkWell(
                onTap: () => _showWidgetGuideDialog(context, isDark),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.brandDark.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.widgets_rounded,
                          color: AppColors.brandDark,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bosh ekran vidjeti (Widget)',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Kun so'zi va takrorlashni ekranga chiqarish",
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
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.lightTextMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // AI Vision & Gemini API Card
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AiScanScreen(),
                        ),
                      );
                    },
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: Color(0xFF7C3AED),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'AI Vision Skaner',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppColors.darkText
                                            : AppColors.lightText,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'YANGI',
                                        style: TextStyle(
                                          color: Color(0xFF7C3AED),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Kitob va lug\'at daftar rasmidan to\'plam yaratish',
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
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.lightTextMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  InkWell(
                    onTap: () => showAiSettingsDialog(
                      context,
                      showSavedSnackBar: true,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.bolt_rounded,
                            size: 20,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Groq & AI Vision sozlamalari',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.tune_rounded,
                            size: 18,
                            color: AppColors.lightTextMuted,
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Theme Switcher Card
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: InkWell(
                onTap: () => theme.toggleTheme(),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        theme.isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        size: 22,
                        color: theme.isDark ? AppColors.accent : Colors.amber,
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Mavzu (Tema)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        theme.isDark ? 'Tungi' : 'Yorug\'',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Sign Out Button
            OutlinedButton.icon(
              onPressed: _confirmSignOut,
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Chiqish'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.destructive,
                side: const BorderSide(
                  color: AppColors.destructive,
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Delete Account Button (Google Play Policy Compliance)
            Center(
              child: TextButton.icon(
                onPressed: _confirmDeleteAccount,
                icon: Icon(
                  Icons.delete_forever_rounded,
                  size: 19,
                  color: AppColors.destructive.withValues(alpha: 0.8),
                ),
                label: Text(
                  'Hisobni butunlay o\'chirish',
                  style: TextStyle(
                    color: AppColors.destructive.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.destructive.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheStat(
    String title,
    String val,
    bool isDark, {
    Color? valueColor,
  }) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor ?? (isDark ? Colors.white : AppColors.lightText),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      ],
    );
  }
}
