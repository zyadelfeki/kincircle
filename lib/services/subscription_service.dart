
import 'package:cloud_firestore/cloud_firestore.dart';

enum SubscriptionStatus {
  active,
  trial,
  inactive,
}

extension SubscriptionStatusX on SubscriptionStatus {
  bool get isEntitled => this != SubscriptionStatus.inactive;

  String get wireValue => switch (this) {
        SubscriptionStatus.active => 'active',
        SubscriptionStatus.trial => 'trial',
        SubscriptionStatus.inactive => 'inactive',
      };
}

class SubscriptionService {
  const SubscriptionService();

  SubscriptionStatus resolve(Map<String, dynamic>? data) {
    if (data == null) {
      return SubscriptionStatus.inactive;
    }

    final SubscriptionStatus? nestedStatus = _readNestedStatus(data['subscription']);
    if (nestedStatus != null) {
      return nestedStatus;
    }

    final SubscriptionStatus? directStatus = _readStatusValue(
      data['subscriptionStatus'] ?? data['status'] ?? data['planStatus'],
    );
    if (directStatus != null) {
      return directStatus;
    }

    final dynamic isPro = data['isPro'];
    if (isPro == true) {
      return SubscriptionStatus.active;
    }

    final DateTime? trialEndsAt = _readDateTime(
      data['trialEndsAt'] ?? data['trialEndAt'] ?? data['trialExpiresAt'],
    );
    if (trialEndsAt != null && trialEndsAt.isAfter(DateTime.now())) {
      return SubscriptionStatus.trial;
    }

    return SubscriptionStatus.inactive;
  }

  bool isEntitled(Map<String, dynamic>? data) => resolve(data).isEntitled;

  Map<String, Object?> encode(SubscriptionStatus status) {
    return <String, Object?>{
      'subscriptionStatus': status.wireValue,
      'isPro': status.isEntitled,
    };
  }

  static SubscriptionStatus? parseWireValue(Object? raw) {
    return _readStatusValue(raw);
  }

  static SubscriptionStatus? _readNestedStatus(Object? raw) {
    if (raw is! Map) {
      return null;
    }

    return _readStatusValue(raw['status'] ?? raw['state'] ?? raw['tier']);
  }

  static SubscriptionStatus? _readStatusValue(Object? raw) {
    final String value = raw?.toString().trim().toLowerCase() ?? '';
    switch (value) {
      case 'active':
      case 'paid':
      case 'pro':
      case 'premium':
      case 'entitled':
      case 'subscribed':
        return SubscriptionStatus.active;
      case 'trial':
      case 'trialing':
      case 'free_trial':
      case 'trial_active':
        return SubscriptionStatus.trial;
      case 'inactive':
      case 'cancelled':
      case 'canceled':
      case 'expired':
      case 'none':
      case 'free':
        return SubscriptionStatus.inactive;
      case '':
        return null;
      default:
        return null;
    }
  }

  static DateTime? _readDateTime(Object? raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    return null;
  }
}
