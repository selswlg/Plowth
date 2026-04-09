import 'package:flutter/foundation.dart';

class ApiConfig {
  static const _baseUrlOverride = String.fromEnvironment('PLOWTH_API_BASE_URL');

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) {
      return _baseUrlOverride;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api/v1';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000/api/v1';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'http://127.0.0.1:8000/api/v1';
    }
  }
}
