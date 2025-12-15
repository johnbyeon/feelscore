import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/emotion_asset_helper.dart';
import '../../services/api_service.dart';
import '../../screens/user_profile_page.dart';

class StatusBar extends StatefulWidget {
  const StatusBar({super.key});

  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  final ApiService _apiService = ApiService();
  String _myEmotion = 'NEUTRAL'; // Default
  List<dynamic> _followersStatuses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final myEmotion = await _apiService.getMyTodayEmotion();
      final followers = await _apiService.getFollowersTodayStatus();

      if (mounted) {
        setState(() {
          _myEmotion = myEmotion;
          _followersStatuses = followers;
          _isLoading = false;
          context.read<UserProvider>().setTodayEmotion(myEmotion);
        });
      }
    } catch (e) {
      print('Failed to fetch status bar data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showEmotionPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '오늘의 기분은 어떠신가요?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                  ),
                  itemCount: EmotionAssetHelper.emotionList.length,
                  itemBuilder: (context, index) {
                    final emotionKey = EmotionAssetHelper.emotionList[index];
                    return Tooltip(
                      message: _getEmotionText(emotionKey),
                      triggerMode: TooltipTriggerMode.longPress,
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(context);
                          try {
                            // Update API
                            await _apiService.updateTodayEmotion(emotionKey);
                            // Update Local
                            setState(() {
                              _myEmotion = emotionKey;
                              context.read<UserProvider>().setTodayEmotion(
                                emotionKey,
                              );
                            });
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('상태 업데이트 실패: $e')),
                            );
                          }
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              EmotionAssetHelper.getAssetPath(emotionKey),
                              width: 40,
                              height: 40,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getEmotionText(emotionKey),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getEmotionText(String key) {
    switch (key) {
      case 'JOY':
        return '기쁨';
      case 'SADNESS':
        return '슬픔';
      case 'ANGER':
        return '화남';
      case 'FEAR':
        return '두려움';
      case 'SURPRISE':
        return '놀람';
      case 'DISGUST':
        return '혐오';
      case 'ANTICIPATION':
        return '기대';
      case 'TRUST':
        return '신뢰';
      case 'LOVE':
        return '사랑';
      case 'OPTIMISM':
        return '낙관';
      case 'PESSIMISM':
        return '비관';
      case 'AWE':
        return '경외';
      case 'REMORSE':
        return '후회';
      case 'SUBMISSION':
        return '굴복';
      case 'CONTEMPT':
        return '경멸';
      case 'AGGRESSION':
        return '공격성';
      case 'NEUTRAL':
        return '중립';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          final myProfileImage = userProvider.profileImageUrl;

          // Merge Me + Followers
          // Item count: 1 (Me) + followers.length
          final itemCount = 1 + _followersStatuses.length;

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: itemCount,
            separatorBuilder: (context, index) => const SizedBox(width: 36),
            itemBuilder: (context, index) {
              // ME
              if (index == 0) {
                return GestureDetector(
                  onTap: _showEmotionPicker,
                  child: _buildStatusItem(
                    isMe: true,
                    name: '나의 상태',
                    imageUrl: myProfileImage,
                    emotion: _myEmotion,
                  ),
                );
              }

              // Follower
              final follower = _followersStatuses[index - 1];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => UserProfilePage(
                            userId: follower['userId'].toString(),
                            nickname: follower['nickname'] ?? 'Unknown',
                            profileImageUrl: follower['profileImageUrl'],
                          ),
                    ),
                  );
                },
                child: _buildStatusItem(
                  isMe: false,
                  name: follower['nickname'] ?? 'Unknown',
                  imageUrl: follower['profileImageUrl'],
                  emotion: follower['emotion'] ?? 'NEUTRAL',
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusItem({
    required bool isMe,
    required String name,
    required String? imageUrl,
    required String emotion,
  }) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isMe ? const Color(0xFFD0BCFF) : Colors.grey[800]!,
                  width: isMe ? 2.5 : 2,
                ),
                color: Colors.grey[300],
              ),
              child:
                  imageUrl != null && imageUrl.isNotEmpty
                      ? ClipOval(
                        child: Image.network(
                          'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/$imageUrl',
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) => const Icon(
                                Icons.person,
                                color: Colors.grey,
                                size: 40,
                              ),
                        ),
                      )
                      : const Icon(Icons.person, color: Colors.grey, size: 40),
            ),
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2), // Outline
                  color: Colors.black, // Background for icon visibility
                ),
                child: Image.asset(
                  EmotionAssetHelper.getAssetPath(emotion),
                  width: 32,
                  height: 32,
                ),
              ),
            ),
            if (isMe)
              Positioned(
                right: -4,
                bottom: -4,
                child: IgnorePointer(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.transparent),
                    ),
                    // Just an overlay to indicate interactivity?
                    // Actually the icon itself shows current status.
                    // Maybe a small 'plus' if neutral?
                    // For now, simpler is better.
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: TextStyle(
            color: isMe ? const Color(0xFFD0BCFF) : Colors.white,
            fontSize: 12,
            fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
