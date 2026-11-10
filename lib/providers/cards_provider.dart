import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/services/supabase_service.dart';
import '../core/services/offline_queue_service.dart';
import '../core/services/cache_service.dart';
import '../core/services/widget_service.dart';
import '../core/utils/srs.dart';
import '../models/card_model.dart';

class CardsProvider extends ChangeNotifier {
  final Map<String, List<CardModel>> _deckCards = {};
  List<CardModel> _allCards = [];
  bool _isLoading = false;
  final Set<String> _initialLoadingDecks = {};
  bool _isAllCardsInitialLoading = false;
  final Map<String, Future<void>> _deckLoadFutures = {};
  final Map<String, DateTime> _deckLoadedAt = {};
  Future<void>? _allCardsLoadFuture;
  String? _allCardsLoadedUserId;
  DateTime? _allCardsLoadedAt;
  int _generation = 0;

  List<CardModel> getCardsForDeck(String deckId) => _deckCards[deckId] ?? [];
  List<CardModel> get allCards => _allCards;
  bool get isLoading => _isLoading;
  bool isDeckInitialLoading(String deckId) =>
      _initialLoadingDecks.contains(deckId);
  bool get isAllCardsInitialLoading => _isAllCardsInitialLoading;

  void clear() {
    _deckCards.clear();
    _allCards = [];
    _isLoading = false;
    _initialLoadingDecks.clear();
    _isAllCardsInitialLoading = false;
    _deckLoadFutures.clear();
    _deckLoadedAt.clear();
    _allCardsLoadFuture = null;
    _allCardsLoadedUserId = null;
    _allCardsLoadedAt = null;
    _generation += 1;
    notifyListeners();
  }

  CardsProvider() {
    _loadFromCache();
  }

  Future<void> _loadFromCache() async {
    final cached = await CacheService.instance.getCachedAllCards();
    if (cached.isNotEmpty && _allCards.isEmpty) {
      _allCards = cached;
      notifyListeners();
    }
  }

  Future<void> loadCardsForDeck(String deckId, {bool force = false}) {
    final inFlight = _deckLoadFutures[deckId];
    if (inFlight != null) return inFlight;
    final loadedAt = _deckLoadedAt[deckId];
    if (!force &&
        loadedAt != null &&
        DateTime.now().difference(loadedAt) < const Duration(seconds: 30)) {
      return Future<void>.value();
    }
    final future = _loadCardsForDeck(deckId, _generation);
    _deckLoadFutures[deckId] = future;
    return future.whenComplete(() {
      if (identical(_deckLoadFutures[deckId], future)) {
        _deckLoadFutures.remove(deckId);
      }
    });
  }

  Future<void> _loadCardsForDeck(String deckId, int generation) async {
    // Fast-path: Show cached deck cards immediately (0ms)
    if (!_deckCards.containsKey(deckId) || _deckCards[deckId]!.isEmpty) {
      final cached = await CacheService.instance.getCachedDeckCards(deckId);
      if (cached.isNotEmpty) {
        _deckCards[deckId] = cached;
        notifyListeners();
      }
    }

    final hasNoCards =
        !_deckCards.containsKey(deckId) || _deckCards[deckId]!.isEmpty;
    if (hasNoCards) {
      _initialLoadingDecks.add(deckId);
    }
    _isLoading = true;
    notifyListeners();

    try {
      final res = await SupabaseService.client
          .from('cards')
          .select(
            'id, user_id, deck_id, word, pronunciation, translation, definition, synonyms, antonyms, example_sentence, ease_factor, interval_days, repetitions, due_date, total_reviews, correct_reviews, created_at, updated_at',
          )
          .eq('deck_id', deckId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 4));

      final list = (res as List)
          .map((e) => CardModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (generation != _generation) return;
      _deckCards[deckId] = list;
      _deckLoadedAt[deckId] = DateTime.now();
      await CacheService.instance.cacheDeckCards(deckId, list);
    } catch (e) {
      debugPrint('Error loading cards for deck $deckId: $e');
      if (generation != _generation) return;
      if (!_deckCards.containsKey(deckId) || _deckCards[deckId]!.isEmpty) {
        _deckCards[deckId] = await CacheService.instance.getCachedDeckCards(
          deckId,
        );
      }
    } finally {
      _initialLoadingDecks.remove(deckId);
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAllCards(String userId, {bool force = false}) {
    if (_allCardsLoadFuture != null) return _allCardsLoadFuture!;
    final loadedRecently =
        _allCardsLoadedUserId == userId &&
        _allCardsLoadedAt != null &&
        DateTime.now().difference(_allCardsLoadedAt!) <
            const Duration(seconds: 30);
    if (!force && loadedRecently) return Future<void>.value();
    final future = _loadAllCards(userId, _generation);
    _allCardsLoadFuture = future;
    return future.whenComplete(() {
      if (identical(_allCardsLoadFuture, future)) _allCardsLoadFuture = null;
    });
  }

  Future<void> _loadAllCards(String userId, int generation) async {
    if (_allCards.isEmpty) {
      final cached = await CacheService.instance.getCachedAllCards();
      if (cached.isNotEmpty) {
        _allCards = cached;
        notifyListeners();
      }
    }

    _isAllCardsInitialLoading = _allCards.isEmpty;

    try {
      final res = await SupabaseService.client
          .from('cards')
          .select(
            'id, user_id, deck_id, word, pronunciation, translation, definition, synonyms, antonyms, example_sentence, ease_factor, interval_days, repetitions, due_date, total_reviews, correct_reviews, created_at, updated_at',
          )
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 4));

      final list = (res as List)
          .map((e) => CardModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (generation != _generation) return;
      _allCards = list;
      _allCardsLoadedUserId = userId;
      _allCardsLoadedAt = DateTime.now();
      await CacheService.instance.cacheAllCards(_allCards);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading all cards: $e');
      if (generation != _generation) return;
      if (_allCards.isEmpty) {
        _allCards = await CacheService.instance.getCachedAllCards();
        notifyListeners();
      }
    } finally {
      _isAllCardsInitialLoading = false;
      notifyListeners();
      unawaited(WidgetService.syncFromCards(_allCards));
    }
  }

  Future<CardModel?> addCard({
    required String userId,
    required String deckId,
    required String word,
    required String translation,
    String? exampleSentence,
    String? pronunciation,
    String? definition,
    String? synonyms,
    String? antonyms,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final today = SrsAlgorithm.todayISO();

    final newCard = CardModel(
      id: id,
      userId: userId,
      deckId: deckId,
      word: word.trim(),
      translation: translation.trim(),
      exampleSentence: exampleSentence?.trim().isEmpty == true
          ? null
          : exampleSentence?.trim(),
      pronunciation: pronunciation?.trim().isEmpty == true
          ? null
          : pronunciation?.trim(),
      definition: definition?.trim().isEmpty == true
          ? null
          : definition?.trim(),
      synonyms: synonyms?.trim().isEmpty == true ? null : synonyms?.trim(),
      antonyms: antonyms?.trim().isEmpty == true ? null : antonyms?.trim(),
      easeFactor: 2.5,
      intervalDays: 0,
      repetitions: 0,
      dueDate: today,
      totalReviews: 0,
      correctReviews: 0,
      createdAt: now,
      updatedAt: now,
    );

    // Optimistic addition
    final currentList = _deckCards[deckId] ?? [];
    _deckCards[deckId] = [newCard, ...currentList];
    _allCards = [newCard, ..._allCards];
    notifyListeners();

    // Cache update
    await CacheService.instance.cacheDeckCards(deckId, _deckCards[deckId]!);
    await CacheService.instance.cacheAllCards(_allCards);

    try {
      await OfflineQueueService.instance.queuedWrite(
        QueuedOp(kind: OpKind.insert, table: 'cards', rows: [newCard.toJson()]),
      );
      OfflineQueueService.instance.flushQueue();
      return newCard;
    } catch (e) {
      debugPrint('Error inserting card: $e');
      return newCard;
    }
  }

  Future<void> updateCard({
    required String cardId,
    required String deckId,
    required String word,
    required String translation,
    String? exampleSentence,
  }) async {
    final currentList = _deckCards[deckId] ?? [];
    _deckCards[deckId] = currentList.map((c) {
      if (c.id == cardId) {
        return c.copyWith(
          word: word.trim(),
          translation: translation.trim(),
          exampleSentence: exampleSentence?.trim(),
        );
      }
      return c;
    }).toList();

    _allCards = _allCards.map((c) {
      if (c.id == cardId) {
        return c.copyWith(
          word: word.trim(),
          translation: translation.trim(),
          exampleSentence: exampleSentence?.trim(),
        );
      }
      return c;
    }).toList();

    notifyListeners();

    // Cache update
    await CacheService.instance.cacheDeckCards(deckId, _deckCards[deckId]!);
    await CacheService.instance.cacheAllCards(_allCards);

    try {
      await OfflineQueueService.instance.queuedWrite(
        QueuedOp(
          kind: OpKind.update,
          table: 'cards',
          match: {'id': cardId},
          values: {
            'word': word.trim(),
            'translation': translation.trim(),
            'example_sentence': exampleSentence?.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          },
        ),
      );
      OfflineQueueService.instance.flushQueue();
    } catch (e) {
      debugPrint('Error updating card: $e');
    }
  }

  Future<void> deleteCard(String cardId, String deckId) async {
    final currentList = _deckCards[deckId] ?? [];
    _deckCards[deckId] = currentList.where((c) => c.id != cardId).toList();
    _allCards = _allCards.where((c) => c.id != cardId).toList();
    notifyListeners();

    // Cache update
    await CacheService.instance.cacheDeckCards(deckId, _deckCards[deckId]!);
    await CacheService.instance.cacheAllCards(_allCards);

    try {
      await OfflineQueueService.instance.queuedWrite(
        QueuedOp(kind: OpKind.delete, table: 'cards', match: {'id': cardId}),
      );
      OfflineQueueService.instance.flushQueue();
    } catch (e) {
      debugPrint('Error deleting card: $e');
    }
  }

  Future<void> removeCardsForDeck(String deckId) async {
    _deckCards.remove(deckId);
    _deckLoadedAt.remove(deckId);
    _deckLoadFutures.remove(deckId);
    _allCards = _allCards.where((c) => c.deckId != deckId).toList();
    notifyListeners();

    await CacheService.instance.removeDeckCardsCache(deckId);
    await CacheService.instance.cacheAllCards(_allCards);
  }

  Future<int> bulkImportCards({
    required String userId,
    required String deckId,
    required List<Map<String, dynamic>> items,
  }) async {
    if (items.isEmpty) return 0;
    final today = SrsAlgorithm.todayISO();
    final now = DateTime.now().toIso8601String();

    final rows = items.map((w) {
      final id = const Uuid().v4();
      final word = w['word']?.toString().trim() ?? '';
      final translation = w['translation']?.toString().trim() ?? '';

      String? formatListOrString(dynamic val) {
        if (val == null) return null;
        if (val is List) return val.where((e) => e != null).join(', ');
        return val.toString();
      }

      return {
        'id': id,
        'user_id': userId,
        'deck_id': deckId,
        'word': word,
        'pronunciation': w['pronunciation']?.toString().trim(),
        'translation': translation,
        'definition': w['definition']?.toString().trim(),
        'synonyms': formatListOrString(w['synonyms']),
        'antonyms': formatListOrString(w['antonyms']),
        'example_sentence': (w['example_sentence'] ?? w['example'])
            ?.toString()
            .trim(),
        'ease_factor': 2.5,
        'interval_days': 0,
        'repetitions': 0,
        'due_date': today,
        'total_reviews': 0,
        'correct_reviews': 0,
        'created_at': now,
        'updated_at': now,
      };
    }).toList();

    final newCards = rows.map((r) => CardModel.fromJson(r)).toList();
    final currentList = _deckCards[deckId] ?? [];
    _deckCards[deckId] = [...newCards, ...currentList];
    _allCards = [...newCards, ..._allCards];
    notifyListeners();

    await CacheService.instance.cacheDeckCards(deckId, _deckCards[deckId]!);
    await CacheService.instance.cacheAllCards(_allCards);

    try {
      await OfflineQueueService.instance.queuedWrite(
        QueuedOp(kind: OpKind.insert, table: 'cards', rows: rows),
      );
      OfflineQueueService.instance.flushQueue();
      return rows.length;
    } catch (e) {
      debugPrint('Error in bulk import: $e');
      return rows.length;
    }
  }
}
