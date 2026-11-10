import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../../models/card_model.dart';
import 'cache_service.dart';

class WidgetService {
  static const String _androidWidgetName = 'VocabifyWidgetProvider';
  static const String _groupId = 'group.com.vocabify.vocabify_app';

  /// Initialize HomeWidget settings
  static Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(_groupId);
    } catch (e) {
      debugPrint('WidgetService init error: $e');
    }
  }

  /// Updates the widget with specific word and stats data
  static Future<void> updateWidgetData({
    required String word,
    required String translation,
    String? pronunciation,
    String? example,
    int streak = 0,
    int dueCount = 0,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('widget_word', word);
      await HomeWidget.saveWidgetData<String>('widget_translation', translation);
      await HomeWidget.saveWidgetData<String>(
        'widget_pronunciation',
        pronunciation ?? '',
      );
      await HomeWidget.saveWidgetData<String>('widget_example', example ?? '');
      await HomeWidget.saveWidgetData<int>('widget_streak', streak);
      await HomeWidget.saveWidgetData<int>('widget_due_count', dueCount);

      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        androidName: _androidWidgetName,
      );
    } catch (e) {
      debugPrint('WidgetService.updateWidgetData error: $e');
    }
  }

  /// Smartly selects a card from user's cards (due cards first, or random),
  /// and synchronizes the Home Screen Widget.
  static Future<void> syncFromCardsAndStreak({
    required List<CardModel> cards,
    required int streak,
  }) async {
    if (cards.isEmpty) {
      await updateWidgetData(
        word: 'Vocabify',
        translation: "So'zlarni yodlashni boshlash uchun to'plam qo'shing!",
        pronunciation: '/voʊˈkæb.ɪ.faɪ/',
        example: 'Start your vocabulary journey today!',
        streak: streak,
        dueCount: 0,
      );
      return;
    }

    // Filter due cards (today or earlier)
    final now = DateTime.now();
    final todayStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final dueCards = cards
        .where((card) => card.dueDate.compareTo(todayStr) <= 0)
        .toList();

    // Pick featured card of the day:
    // If due cards exist, pick the first due card; otherwise pick a random card.
    final featuredCard = dueCards.isNotEmpty
        ? dueCards.first
        : cards[Random().nextInt(cards.length)];

    await updateWidgetData(
      word: featuredCard.word,
      translation: featuredCard.translation,
      pronunciation: featuredCard.pronunciation,
      example: featuredCard.exampleSentence ?? featuredCard.mySentence,
      streak: streak,
      dueCount: dueCards.length,
    );
  }

  /// Convenience method that automatically reads the streak from cached profile
  static Future<void> syncFromCards(List<CardModel> cards) async {
    final profile = await CacheService.instance.getCachedProfile();
    final streak = profile?.currentStreak ?? 0;
    await syncFromCardsAndStreak(cards: cards, streak: streak);
  }
}
