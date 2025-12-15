import 'package:flutter/material.dart';
import '../../utils/emotion_asset_helper.dart';

class EmotionStickerPicker extends StatefulWidget {
  final Function(String) onStickerSelected;

  const EmotionStickerPicker({super.key, required this.onStickerSelected});

  @override
  State<EmotionStickerPicker> createState() => _EmotionStickerPickerState();
}

class _EmotionStickerPickerState extends State<EmotionStickerPicker> {
  List<String> _filteredList = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredList = EmotionAssetHelper.emotionList;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterEmotions(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredList = EmotionAssetHelper.emotionList;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();

    setState(() {
      _filteredList =
          EmotionAssetHelper.emotionList.where((emotion) {
            // 1. Check Key (e.g. JOY)
            if (emotion.toLowerCase().contains(lowerQuery)) return true;

            // 2. Check Korean Label
            final label = _getEmotionLabel(emotion);
            if (label.contains(query)) return true;

            // 3. Check Synonyms/Related Words
            final synonyms = _getSynonyms(emotion);
            if (synonyms.any((s) => s.contains(query))) return true;

            return false;
          }).toList();
    });
  }

  List<String> _getSynonyms(String key) {
    switch (key) {
      case 'JOY':
        return ['행복', '웃음', '신남', '즐거움', 'happy', 'smile'];
      case 'SADNESS':
        return ['우울', '울음', '눈물', '비', 'sad', 'cry'];
      case 'ANGER':
        return ['화', '짜증', '열받아', 'angry'];
      case 'FEAR':
        return ['무서움', '공포', '겁', 'fear'];
      case 'DISGUST':
        return ['싫어', '우엑', 'disgust'];
      case 'SURPRISE':
        return ['깜짝', '대박', '헐', 'surprise'];
      case 'CONTEMPT':
        return ['무시', '흥', '칫'];
      case 'LOVE':
        return ['좋아', '하트', '설렘', 'love', 'like'];
      case 'ANTICIPATION':
        return ['기대', '두근', '설레'];
      case 'TRUST':
        return ['믿음', '운명', '약속'];
      case 'NEUTRAL':
        return ['그저그래', '보통', '무표정'];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterEmotions,
                decoration: const InputDecoration(
                  icon: Icon(Icons.search, color: Colors.grey),
                  hintText: '이모티콘 검색 (예: 웃음, 사랑)',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),

          Expanded(
            child:
                _filteredList.isEmpty
                    ? const Center(
                      child: Text(
                        '검색 결과가 없습니다.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                    : GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: _filteredList.length,
                      itemBuilder: (context, index) {
                        final emotion = _filteredList[index];
                        final assetPath = EmotionAssetHelper.getAssetPath(
                          emotion,
                        );

                        return GestureDetector(
                          onTap: () {
                            widget.onStickerSelected('($emotion)');
                          },
                          child: Column(
                            children: [
                              Expanded(
                                child: Image.asset(
                                  assetPath,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getEmotionLabel(emotion),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  String _getEmotionLabel(String key) {
    switch (key) {
      case 'JOY':
        return '기쁨';
      case 'SADNESS':
        return '슬픔';
      case 'ANGER':
        return '분노';
      case 'FEAR':
        return '두려움';
      case 'DISGUST':
        return '혐오';
      case 'SURPRISE':
        return '놀람';
      case 'CONTEMPT':
        return '경멸';
      case 'LOVE':
        return '사랑';
      case 'ANTICIPATION':
        return '기대';
      case 'TRUST':
        return '신뢰';
      case 'NEUTRAL':
        return '중립';
      default:
        return key;
    }
  }
}
