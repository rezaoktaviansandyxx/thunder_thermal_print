class PrinterLogger {
  static bool _enabled = false;
  static String _tag = 'ThunderThermalPrint';

  PrinterLogger._();

  static void enable() {
    _enabled = true;
  }

  static void disable() {
    _enabled = false;
  }

  static bool get isEnabled => _enabled;

  static void setTag(String tag) {
    _tag = tag;
  }

  static void d(String message) {
    if (_enabled) {
      print('[DEBUG] $_tag: $message');
    }
  }

  static void i(String message) {
    if (_enabled) {
      print('[INFO] $_tag: $message');
    }
  }

  static void w(String message) {
    if (_enabled) {
      print('[WARN] $_tag: $message');
    }
  }

  static void e(String message, [Object? error]) {
    if (_enabled) {
      print('[ERROR] $_tag: $message');
      if (error != null) {
        print('[ERROR] $_tag: $error');
      }
    }
  }
}
