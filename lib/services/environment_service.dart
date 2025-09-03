import '../firebase_options.dart';

class EnvironmentService {
  static const String _prodProjectId = 'fitfusion-prod-2024';
  static const String _devProjectId = 'fitfusion-dev';
  static const String _demoProjectId = 'fitfusion-demo';

  static EnvironmentType get currentEnvironment {
    final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
    
    switch (projectId) {
      case _prodProjectId:
        return EnvironmentType.production;
      case _devProjectId:
        return EnvironmentType.development;
      case _demoProjectId:
        return EnvironmentType.demo;
      default:
        return EnvironmentType.development;
    }
  }

  static bool get isProduction => currentEnvironment == EnvironmentType.production;
  static bool get isDevelopment => currentEnvironment == EnvironmentType.development;
  static bool get isDemo => currentEnvironment == EnvironmentType.demo;

  static String get appName {
    switch (currentEnvironment) {
      case EnvironmentType.production:
        return 'FitFusion';
      case EnvironmentType.development:
        return 'FitFusion (Dev)';
      case EnvironmentType.demo:
        return 'FitFusion (Demo)';
    }
  }

  static String get supportEmail {
    switch (currentEnvironment) {
      case EnvironmentType.production:
        return 'support@fitfusion.app';
      case EnvironmentType.development:
        return 'dev-support@fitfusion.app';
      case EnvironmentType.demo:
        return 'demo@fitfusion.app';
    }
  }

  static String get baseUrl {
    switch (currentEnvironment) {
      case EnvironmentType.production:
        return 'https://fitfusion.app';
      case EnvironmentType.development:
        return 'https://dev-fitfusion.web.app';
      case EnvironmentType.demo:
        return 'https://demo-fitfusion.web.app';
    }
  }

  static Map<String, String> get analyticsConfig {
    return {
      'environment': currentEnvironment.name,
      'version': '1.0.0',
      'debug': (!isProduction).toString(),
    };
  }

  static Map<String, dynamic> get errorReportingConfig {
    return {
      'enabled': isProduction,
      'environment': currentEnvironment.name,
      'release': '1.0.0',
      'dsn': isProduction ? 'YOUR_SENTRY_DSN_HERE' : null,
    };
  }

  static Map<String, dynamic> get performanceConfig {
    return {
      'enabled': isProduction,
      'sampleRate': isProduction ? 0.1 : 1.0, // 10% in prod, 100% in dev
      'environment': currentEnvironment.name,
    };
  }
}

enum EnvironmentType {
  production,
  development,
  demo;

  String get name => toString().split('.').last;
}