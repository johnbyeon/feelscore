import 'package:flutter/material.dart';

class RefreshProvider extends ChangeNotifier {
  bool _shouldRefreshHistory = false;

  bool _shouldRefreshHome = false;

  bool get shouldRefreshHistory => _shouldRefreshHistory;
  bool get shouldRefreshHome => _shouldRefreshHome;

  void triggerRefreshHistory() {
    _shouldRefreshHistory = true;
    notifyListeners();
  }

  void consumeRefreshHistory() {
    _shouldRefreshHistory = false;
  }

  void triggerRefreshHome() {
    _shouldRefreshHome = true;
    notifyListeners();
  }

  void consumeRefreshHome() {
    _shouldRefreshHome = false;
  }

  bool _shouldRefreshProfile = false;
  bool get shouldRefreshProfile => _shouldRefreshProfile;

  void triggerRefreshProfile() {
    _shouldRefreshProfile = true;
    notifyListeners();
  }

  void consumeRefreshProfile() {
    _shouldRefreshProfile = false;
  }
}
