import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';

/// Companion personalities for different user needs
enum CompanionPersonality {
  sage,  // Wise, calming presence (Default for elderly)
  spark, // Energetic motivator (Default for ADHD)
  grove, // Nature-loving guide (Default for anxious)
  echo,  // Understanding listener (Default for depressed)
}

/// Companion profile with personality-specific content
class CompanionProfile {
  final CompanionPersonality personality;
  final String name;
  final String avatar;
  final List<String> greetingMessages;
  final List<String> encouragementMessages;
  final List<String> celebrationMessages;
  final List<String> comfortMessages;
  final List<String> empathyMessages;

  const CompanionProfile({
    required this.personality,
    required this.name,
    required this.avatar,
    required this.greetingMessages,
    required this.encouragementMessages,
    required this.celebrationMessages,
    required this.comfortMessages,
    required this.empathyMessages,
  });

  static CompanionProfile forPersonality(CompanionPersonality personality) {
    switch (personality) {
      case CompanionPersonality.sage:
        return _sageProfile;
      case CompanionPersonality.spark:
        return _sparkProfile;
      case CompanionPersonality.grove:
        return _groveProfile;
      case CompanionPersonality.echo:
        return _echoProfile;
    }
  }

  static const CompanionProfile _sageProfile = CompanionProfile(
    personality: CompanionPersonality.sage,
    name: 'Sage',
    avatar: '🧙',
    greetingMessages: [
      'Welcome back, wise one. Your family awaits.',
      'Greetings! The day holds much promise.',
      'Hello, dear friend. Your presence brings calm.',
      'Welcome. Time flows differently when we cherish it.',
      'Ah, you return. The circle is complete again.',
    ],
    encouragementMessages: [
      'Your consistency speaks of deep wisdom.',
      'Each connection you make strengthens the bond.',
      'You bring light to your family circle.',
      'Your patience is a gift to those you love.',
      'Wisdom grows with every caring gesture.',
      'The way you nurture relationships is beautiful.',
      'You understand what truly matters in life.',
    ],
    celebrationMessages: [
      'A magnificent achievement! Your dedication shines.',
      'Remarkable! This milestone reflects your commitment.',
      'Splendid progress! Your family feels your love.',
      'Well done! True wisdom is shown through action.',
      'Extraordinary! You exemplify family devotion.',
    ],
    comfortMessages: [
      'Rest is part of wisdom. Take your time.',
      'It\'s perfectly fine to pause and reflect.',
      'Your well-being matters. Be gentle with yourself.',
      'Even the wisest need moments of peace.',
      'Remember, caring for yourself helps you care for others.',
    ],
    empathyMessages: [
      'I see how much love you hold in your heart.',
      'Your caring nature is truly remarkable.',
      'The effort you put into family is beautiful.',
      'You carry your responsibilities with grace.',
      'Your presence makes a profound difference.',
    ],
  );

  static const CompanionProfile _sparkProfile = CompanionProfile(
    personality: CompanionPersonality.spark,
    name: 'Spark',
    avatar: '⚡',
    greetingMessages: [
      'Hey there! Ready to make today amazing?!',
      'Welcome back, superstar! Let\'s do this!',
      'You\'re here! Time to create some magic!',
      'Hi! Your energy lights up the whole app!',
      'Welcome! Today\'s going to be AWESOME!',
    ],
    encouragementMessages: [
      'You\'re absolutely crushing it! Keep going!',
      'WOW! Look at you go! So impressive!',
      'That\'s what I\'m talking about! You rock!',
      'Your energy is contagious! Love it!',
      'Yes! You\'re making incredible progress!',
      'Amazing work! You\'re unstoppable!',
      'I\'m so proud of you! Keep that momentum!',
    ],
    celebrationMessages: [
      'WOOHOO! You did it! This is HUGE!',
      'YES! YES! YES! You\'re incredible!',
      'Can we talk about how AMAZING this is?!',
      'I KNEW you could do it! Celebration time!',
      'This calls for a party! You\'re fantastic!',
    ],
    comfortMessages: [
      'Hey, it\'s totally okay to take a breather!',
      'You know what? Rest is productive too!',
      'No pressure! You\'re doing great anyway!',
      'Taking breaks makes you even more awesome!',
      'Recharge time! You\'ve earned it, champ!',
    ],
    empathyMessages: [
      'I see you putting in the effort. That\'s awesome!',
      'Your enthusiasm for family is inspiring!',
      'The energy you bring is so special!',
      'You care so much, and it shows!',
      'Your dedication is absolutely beautiful!',
    ],
  );

  static const CompanionProfile _groveProfile = CompanionProfile(
    personality: CompanionPersonality.grove,
    name: 'Grove',
    avatar: '🌿',
    greetingMessages: [
      'Welcome, dear friend. Nature smiles upon you.',
      'Hello! Like a tree, your roots grow deeper.',
      'Greetings! The forest whispers your name.',
      'Welcome back. Breathe in, breathe out, be present.',
      'Hi there. May peace flow through you like water.',
    ],
    encouragementMessages: [
      'Like seasons changing, you grow naturally.',
      'Your care blooms like flowers in spring.',
      'Every connection you nurture takes root.',
      'You tend to relationships like a garden.',
      'Your calm presence is a gift to all.',
      'Like ancient trees, your bonds strengthen.',
      'You bring serenity wherever you go.',
    ],
    celebrationMessages: [
      'A beautiful milestone! Nature celebrates with you.',
      'Wonderful! Your growth is like a forest thriving.',
      'Magnificent! You\'ve reached a peaceful summit.',
      'How lovely! Your journey bears sweet fruit.',
      'Splendid! Like dawn breaking, this is beautiful.',
    ],
    comfortMessages: [
      'Rest like the earth in winter. It\'s natural.',
      'Even trees need stillness. Take your time.',
      'Be gentle, like rain on leaves.',
      'Pause and breathe. The forest is patient.',
      'Quietness is healing. Embrace this moment.',
    ],
    empathyMessages: [
      'I feel the care you pour into relationships.',
      'Your gentle approach is truly healing.',
      'The tranquility you seek, you also give.',
      'Your presence is calming, like a forest path.',
      'You understand the rhythm of connection.',
    ],
  );

  static const CompanionProfile _echoProfile = CompanionProfile(
    personality: CompanionPersonality.echo,
    name: 'Echo',
    avatar: '💙',
    greetingMessages: [
      'Hello, friend. I\'m here, listening.',
      'Welcome back. Your feelings are valid.',
      'Hi there. I understand, and I care.',
      'Welcome. You\'re not alone in this.',
      'Hello. Take your time, I\'m here for you.',
    ],
    encouragementMessages: [
      'I see your effort, even when it\'s hard.',
      'You\'re doing better than you think.',
      'Every small step matters. You matter.',
      'I understand how much you care.',
      'Your feelings are important. You\'re important.',
      'It\'s okay to go at your own pace.',
      'I hear you, and I believe in you.',
    ],
    celebrationMessages: [
      'I\'m so proud of you. This matters.',
      'You did this! That took real courage.',
      'This achievement is meaningful. You are.',
      'I knew you had it in you. Well done.',
      'You should feel proud. I certainly am.',
    ],
    comfortMessages: [
      'It\'s okay to not be okay sometimes.',
      'Be kind to yourself. You deserve it.',
      'I\'m here, no judgment, just support.',
      'Your feelings are valid, always.',
      'Take all the time you need. I\'ll wait.',
    ],
    empathyMessages: [
      'I hear the depth of your caring.',
      'Your emotions show your beautiful heart.',
      'It\'s clear how much you love your family.',
      'I understand the weight you carry.',
      'Your sensitivity is a strength, not weakness.',
    ],
  );
}

/// Service for managing AI companion interactions
class CompanionService extends ChangeNotifier {
  static final CompanionService _instance = CompanionService._internal();
  factory CompanionService() => _instance;
  CompanionService._internal() {
    _listenAuthChanges();
  }

  CompanionPersonality _personality = CompanionPersonality.sage;
  CompanionProfile? _profile;
  int _relationshipScore = 0;
  DateTime? _lastInteraction;
  final List<String> _messageHistory = [];
  StreamSubscription? _companionSubscription;
  StreamSubscription<User?>? _authSubscription;

  void _listenAuthChanges() {
    try {
      _authSubscription?.cancel();
      _authSubscription =
          FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (user == null) {
          _companionSubscription?.cancel();
          _companionSubscription = null;
        }
      });
    } catch (_) {
      // Firebase not initialized in unit tests
    }
  }

  // Getters
  CompanionPersonality get personality => _personality;
  CompanionProfile get profile => _profile ?? CompanionProfile.forPersonality(_personality);
  int get relationshipScore => _relationshipScore;
  DateTime? get lastInteraction => _lastInteraction;
  List<String> get recentMessages => _messageHistory;

  /// Initialize the service
  Future<void> initialize() async {
    try {
      await _loadCompanionProfile();
      _listenToCompanionChanges();

      if (kDebugMode) {
        debugPrint('CompanionService initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing CompanionService: $e');
      }
    }
  }

  /// Load companion profile from Firestore
  Future<void> _loadCompanionProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('companion')
          .doc('profile')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _personality = CompanionPersonality.values.firstWhere(
          (e) => e.name == data['personality'],
          orElse: () => CompanionPersonality.sage,
        );
        _relationshipScore = data['relationshipScore'] ?? 0;
        _lastInteraction = (data['lastInteraction'] as Timestamp?)?.toDate();
        _messageHistory.clear();
        _messageHistory.addAll((data['messageHistory'] as List?)?.cast<String>() ?? []);
        _profile = CompanionProfile.forPersonality(_personality);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading companion profile: $e');
      }
    }
  }

  /// Listen to real-time companion changes
  void _listenToCompanionChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _companionSubscription?.cancel();
      _companionSubscription = null;
      return;
    }

    _companionSubscription?.cancel();
    _companionSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('companion')
        .doc('profile')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        _personality = CompanionPersonality.values.firstWhere(
          (e) => e.name == data['personality'],
          orElse: () => CompanionPersonality.sage,
        );
        _relationshipScore = data['relationshipScore'] ?? 0;
        _profile = CompanionProfile.forPersonality(_personality);
        notifyListeners();
      }
    }, onError: (_) {});
  }

  /// Select companion personality
  Future<void> selectPersonality(CompanionPersonality personality) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('companion')
          .doc('profile')
          .set({
        'personality': personality.name,
        'relationshipScore': 0,
        'lastInteraction': FieldValue.serverTimestamp(),
        'messageHistory': [],
      }, SetOptions(merge: true));

      _personality = personality;
      _profile = CompanionProfile.forPersonality(personality);
      _relationshipScore = 0;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error selecting companion: $e');
      }
    }
  }

  /// Get greeting message
  String getGreeting() {
    final messages = profile.greetingMessages;
    return _getRandomMessage(messages);
  }

  /// Get encouragement message
  String getEncouragement() {
    final messages = profile.encouragementMessages;
    return _getRandomMessage(messages);
  }

  /// Get celebration message
  String getCelebration() {
    _increaseRelationship(5);
    final messages = profile.celebrationMessages;
    return _getRandomMessage(messages);
  }

  /// Get comfort message
  String getComfort() {
    final messages = profile.comfortMessages;
    return _getRandomMessage(messages);
  }

  /// Get empathy message
  String getEmpathy() {
    final messages = profile.empathyMessages;
    return _getRandomMessage(messages);
  }

  /// Get contextual message based on user state
  Future<String> getContextualMessage(String context) async {
    String message;
    switch (context) {
      case 'achievement':
        message = getCelebration();
        break;
      case 'stress':
        message = getComfort();
        break;
      case 'activity':
        message = getEncouragement();
        break;
      default:
        message = getGreeting();
    }

    await _recordMessage(message);
    return message;
  }

  /// Increase relationship score
  void _increaseRelationship(int points) {
    _relationshipScore = (_relationshipScore + points).clamp(0, 100);
    _saveRelationshipScore();
    notifyListeners();
  }

  /// Save relationship score to Firestore
  Future<void> _saveRelationshipScore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('companion')
          .doc('profile')
          .update({
        'relationshipScore': _relationshipScore,
        'lastInteraction': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving relationship score: $e');
      }
    }
  }

  /// Record message in history
  Future<void> _recordMessage(String message) async {
    _messageHistory.insert(0, message);
    if (_messageHistory.length > 10) {
      _messageHistory.removeLast();
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('companion')
          .doc('profile')
          .update({
        'messageHistory': _messageHistory,
        'lastInteraction': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error recording message: $e');
      }
    }
  }

  /// Get random message avoiding recent repeats
  String _getRandomMessage(List<String> messages) {
    if (messages.isEmpty) return 'Hello!';

    // Filter out recently shown messages
    final available = messages.where((msg) => !_messageHistory.contains(msg)).toList();
    final pool = available.isNotEmpty ? available : messages;

    return pool[Random().nextInt(pool.length)];
  }

  /// Record user interaction (increases relationship)
  Future<void> recordInteraction() async {
    _lastInteraction = DateTime.now();
    _increaseRelationship(1);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _companionSubscription?.cancel();
    super.dispose();
  }
}
