import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseService {
  static const String productMonthly = 'pro_monthly';
  static const String productAnnual = 'pro_annual';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  void init() {
    _sub ??= _iap.purchaseStream.listen(_onPurchases, onDone: () {
      _sub?.cancel();
    }, onError: (e) {
      if (kDebugMode) debugPrint('IAP error: $e');
    });
  }

  Future<void> dispose() async {
    await _sub?.cancel();
  }

  Future<ProductDetailsResponse> queryProducts() {
    return _iap.queryProductDetails({productMonthly, productAnnual});
  }

  Future<void> buy(String productId) async {
    final available = await _iap.isAvailable();
    if (!available) throw Exception('Store not available');
    final resp = await queryProducts();
    if (resp.error != null) throw Exception(resp.error!.message);
    final product = resp.productDetails.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Product not found: $productId'),
    );
    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> buyMonthly() => buy(productMonthly);
  Future<void> buyAnnual() => buy(productAnnual);

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _entitlePro();
          await _iap.completePurchase(p);
          break;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
        case PurchaseStatus.pending:
          break;
      }
    }
  }

  Future<void> _entitlePro() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'isPro': true,
      'proSince': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
