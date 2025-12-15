import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class FollowProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Stores the truth. If a userId is in here, we trust this value.
  final Map<String, bool> _followStatus = {};

  // Tracks requests in flight to prevent duplicates.
  final Set<String> _pendingFetches = {};

  bool isFollowing(String userId) {
    return _followStatus[userId] ?? false;
  }

  Future<void> checkFollowStatus(String userId) async {
    // If we already have a status (from previous fetch or user toggle), do nothing.
    if (_followStatus.containsKey(userId)) return;

    // If a request is already in flight for this user, do nothing.
    if (_pendingFetches.contains(userId)) return;

    _pendingFetches.add(userId);

    try {
      final stats = await _apiService.getFollowStats(userId);

      // CRITICAL: Before writing, check if the user toggled the button while we were waiting.
      // If `_followStatus` now contains the key (meaning `toggleFollow` ran),
      // we MUST NOT overwrite it with stale server data.
      if (_followStatus.containsKey(userId)) {
        _pendingFetches.remove(userId);
        return;
      }

      final bool status = stats['isFollowing'] == true;
      _followStatus[userId] = status;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching follow status for $userId: $e');
      }
    } finally {
      _pendingFetches.remove(userId);
    }
  }

  Future<void> toggleFollow(String userId) async {
    final bool currentStatus = isFollowing(userId);

    // Optimistic Update: Explicitly set the value in the map.
    // This acts as a lock against `checkFollowStatus` overwriting it.
    _followStatus[userId] = !currentStatus;
    notifyListeners();

    try {
      // The API returns the NEW follow status (true=following, false=not following)
      final newStatus = await _apiService.toggleFollow(userId);

      // Update local state to match authoritative server state
      if (_followStatus[userId] != newStatus) {
        _followStatus[userId] = newStatus;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling follow for $userId: $e');
      }
      // Revert on error
      _followStatus[userId] = currentStatus;
      notifyListeners();
    }
  }
}
