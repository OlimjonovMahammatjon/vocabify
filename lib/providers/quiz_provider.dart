import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/services/supabase_service.dart';
import '../core/services/offline_queue_service.dart';
import '../core/services/cache_service.dart';
import '../models/card_model.dart';
import '../models/deck_model.dart';

class QuizQuestion {
  final CardModel card;
  final List<String> options;
  final String correctAnswer;

  QuizQuestion({
    required this.card,
    required this.options,
    required this.correctAnswer,
  });
}

class QuizResultItem {
  final CardModel card;
  final String selectedAnswer;
  final bool isCorrect;

  QuizResultItem({
    required this.card,
    required this.selectedAnswer,
    required this.isCorrect,
  });
}

class QuizProvider extends ChangeNotifier {
  DeckModel? _deck;
  String _direction = 'en-uz'; // 'en-uz' or 'uz-en'
  List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  String? _selectedAnswer;
  bool _isAnswered = false;
  int _timeLeft = 30;
  final List<QuizResultItem> _results = [];

  Timer? _timer;
  Timer? _advanceTimer;

  DeckModel? get deck => _deck;
  String get direction => _direction;
  List<QuizQuestion> get questions => _questions;
  int get currentIndex => _currentIndex;
  String? get selectedAnswer => _selectedAnswer;
  bool get isAnswered => _isAnswered;
  int get timeLeft => _timeLeft;
  List<QuizResultItem> get results => _results;

  QuizQuestion? get currentQuestion =>
      (_currentIndex >= 0 && _currentIndex < _questions.length)
      ? _questions[_currentIndex]
      : null;

  bool get isQuizFinished =>
      _questions.isNotEmpty && _currentIndex >= _questions.length;

  void clear() {
    _timer?.cancel();
    _advanceTimer?.cancel();
    _deck = null;
    _questions = [];
    _results.clear();
    _currentIndex = 0;
    _selectedAnswer = null;
    _isAnswered = false;
    notifyListeners();
  }

  void initQuiz({
    required DeckModel deck,
    required List<CardModel> cards,
    required String direction,
  }) {
    _advanceTimer?.cancel();
    _deck = deck;
    _direction = direction;
    _currentIndex = 0;
    _selectedAnswer = null;
    _isAnswered = false;
    _timeLeft = 30;
    _results.clear();

    final shuffled = List<CardModel>.from(cards)..shuffle();
    _questions = shuffled.map((card) {
      final correctAnswer =
          (direction == 'en-uz' ? card.translation : card.word).trim();

      // Collect distinct wrong answers that do not duplicate the correct answer
      final wrongAnswerSet = <String>{};
      final others = cards.where((c) => c.id != card.id).toList()..shuffle();
      for (final other in others) {
        final ans =
            (direction == 'en-uz' ? other.translation : other.word).trim();
        if (ans.isNotEmpty &&
            ans.toLowerCase() != correctAnswer.toLowerCase()) {
          wrongAnswerSet.add(ans);
          if (wrongAnswerSet.length == 3) break;
        }
      }

      final options = [correctAnswer, ...wrongAnswerSet]..shuffle();

      return QuizQuestion(
        card: card,
        options: options,
        correctAnswer: correctAnswer,
      );
    }).toList();

    _startTimer();
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timeLeft <= 1) {
        _handleTimeout();
      } else {
        _timeLeft -= 1;
        notifyListeners();
      }
    });
  }

  void _handleTimeout() {
    _timer?.cancel();
    if (_isAnswered || currentQuestion == null) return;

    final q = currentQuestion!;
    _selectedAnswer = '';
    _isAnswered = true;
    _results.add(
      QuizResultItem(card: q.card, selectedAnswer: '', isCorrect: false),
    );
    notifyListeners();

    _advanceTimer?.cancel();
    _advanceTimer = Timer(const Duration(milliseconds: 1200), () {
      _nextQuestion();
    });
  }

  void selectOption(String option) {
    if (_isAnswered || currentQuestion == null) return;
    _timer?.cancel();

    final q = currentQuestion!;
    final isCorrect = option == q.correctAnswer;
    _selectedAnswer = option;
    _isAnswered = true;

    _results.add(
      QuizResultItem(
        card: q.card,
        selectedAnswer: option,
        isCorrect: isCorrect,
      ),
    );
    notifyListeners();

    _advanceTimer?.cancel();
    _advanceTimer = Timer(const Duration(milliseconds: 1200), () {
      _nextQuestion();
    });
  }

  void _nextQuestion() {
    if (_currentIndex + 1 < _questions.length) {
      _currentIndex += 1;
      _selectedAnswer = null;
      _isAnswered = false;
      _startTimer();
      notifyListeners();
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    _timer?.cancel();
    notifyListeners();

    final userId = SupabaseService.currentUser?.id;
    if (userId != null && _results.isNotEmpty) {
      final now = DateTime.now().toIso8601String();

      // 1. Batch insert reviews
      final reviewRows = _results
          .map(
            (r) => {
              'id': const Uuid().v4(),
              'user_id': userId,
              'card_id': r.card.id,
              'rating': r.isCorrect ? 2 : 0,
              'reviewed_at': now,
            },
          )
          .toList();

      OfflineQueueService.instance.queuedWrite(
        QueuedOp(kind: OpKind.insert, table: 'reviews', rows: reviewRows),
      );

      // 2. Update card stats in DB and local cache
      for (final r in _results) {
        OfflineQueueService.instance.queuedWrite(
          QueuedOp(
            kind: OpKind.update,
            table: 'cards',
            match: {'id': r.card.id},
            values: {
              'total_reviews': r.card.totalReviews + 1,
              'correct_reviews': r.card.correctReviews + (r.isCorrect ? 1 : 0),
              'updated_at': now,
            },
          ),
        );

        final updatedCard = r.card.copyWith(
          totalReviews: r.card.totalReviews + 1,
          correctReviews: r.card.correctReviews + (r.isCorrect ? 1 : 0),
          updatedAt: DateTime.tryParse(now),
        );
        CacheService.instance.updateSingleCachedCard(updatedCard);
      }
      OfflineQueueService.instance.flushQueue();
    }

    _currentIndex = _questions.length; // Mark finished
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _advanceTimer?.cancel();
    super.dispose();
  }
}
