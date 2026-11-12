import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/services/ai_scan_service.dart';

/// Shows the shared AI provider & API key settings dialog.
/// Returns `true` if the user saved settings, `false` otherwise.
Future<bool?> showAiSettingsDialog(
  BuildContext context, {
  bool showSavedSnackBar = false,
}) async {
  final groqKey = await AiScanService.instance.getGroqApiKey();
  final geminiKey = await AiScanService.instance.getGeminiApiKey();
  final activeProvider = await AiScanService.instance.getActiveProvider();

  if (!context.mounted) return false;

  final groqController = TextEditingController(text: groqKey);
  final geminiController = TextEditingController(text: geminiKey);
  var selectedProvider = activeProvider;
  var obscureGroq = true;
  var obscureGemini = true;

  try {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 26),
                  SizedBox(width: 8),
                  Expanded(child: Text('AI Sozlamalari')),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSecondary
                            : AppColors.lightSecondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ProviderTabButton(
                              label: 'Groq (Tezkor)',
                              icon: Icons.bolt_rounded,
                              iconColor: const Color(0xFFF59E0B),
                              isSelected: selectedProvider == AiProvider.groq,
                              isDark: isDark,
                              onTap: () => setDialogState(
                                () => selectedProvider = AiProvider.groq,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _ProviderTabButton(
                              label: 'Gemini',
                              icon: Icons.auto_awesome_rounded,
                              iconColor: AppColors.brand,
                              isSelected: selectedProvider == AiProvider.gemini,
                              isDark: isDark,
                              onTap: () => setDialogState(
                                () => selectedProvider = AiProvider.gemini,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (selectedProvider == AiProvider.groq) ...[
                      Text(
                        '⚡ Groq LPU (Qwen 3.8 / Llama 4 Vision va Llama 3.3) orqali rasm skanerlash hamda so\'z tarjima/misollarini soniyalar ichida bajaradi.\n\nKalitni console.groq.com/keys dan bepul olishingiz mumkin:',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: groqController,
                        obscureText: obscureGroq,
                        decoration: InputDecoration(
                          labelText: 'Groq API Key (gsk_...)',
                          hintText: 'gsk_...',
                          prefixIcon: const Icon(Icons.key_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureGroq
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () => setDialogState(
                              () => obscureGroq = !obscureGroq,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        '✨ Google Gemini (2.5 Flash / 2.0 Flash) orqali rasm skanerlash va so\'z tarjima/misollarini yaratadi.\n\nKalitni aistudio.google.com dan olishingiz mumkin:',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: geminiController,
                        obscureText: obscureGemini,
                        decoration: InputDecoration(
                          labelText: 'Gemini API Key (AIzaSy...)',
                          hintText: 'AIzaSy...',
                          prefixIcon: const Icon(Icons.key_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureGemini
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () => setDialogState(
                              () => obscureGemini = !obscureGemini,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Bekor qilish'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await AiScanService.instance.saveGroqApiKey(
                      groqController.text.trim(),
                    );
                    await AiScanService.instance.saveGeminiApiKey(
                      geminiController.text.trim(),
                    );
                    await AiScanService.instance.setActiveProvider(
                      selectedProvider,
                    );
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  },
                  child: const Text('Saqlash'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && showSavedSnackBar && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI sozlamalari muvaffaqiyatli saqlandi! ⚡'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return saved;
  } finally {
    groqController.dispose();
    geminiController.dispose();
  }
}

class _ProviderTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ProviderTabButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.brandDark : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

