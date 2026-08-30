import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kincircle/services/consent_service.dart';
import 'package:kincircle/services/consent_management_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ConsentService sets and reads consent from SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ConsentService();

    expect(await service.isConsentGiven(), isFalse);
    await service.setConsentGiven();
    expect(await service.isConsentGiven(), isTrue);
    await service.setConsent(false);
    expect(await service.isConsentGiven(), isFalse);
  });

  test('ConsentManagementService reads local cached consents when offline', () async {
    SharedPreferences.setMockInitialValues({
      'consent_locationTracking': true,
      'consent_analytics': false,
    });

    final status = await ConsentManagementService.getConsentStatus('test_user');
    expect(status[ConsentType.locationTracking], isTrue);
    expect(status[ConsentType.analytics], isFalse);
  });
}
