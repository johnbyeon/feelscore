import 'package:flutter/material.dart';

class RefreshProvider extends ChangeNotifier {
  bool _shouldRefreshHistory = false;

  bool get shouldRefreshHistory => _shouldRefreshHistory;

  void triggerRefreshHistory() {
    _shouldRefreshHistory = true;
    notifyListeners();
  }

  void consumeRefreshHistory() {
    _shouldRefreshHistory = false;
    // No notifyListeners here to avoid loops, just resetting the flag
  }
}
