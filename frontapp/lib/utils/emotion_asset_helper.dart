class EmotionAssetHelper {
  static const Map<String, String> _emotionToAsset = {
    'JOY': 'assets/images/01.png',
    'SADNESS': 'assets/images/02.png',
    'ANGER': 'assets/images/03.png',
    'FEAR': 'assets/images/04.png',
    'DISGUST': 'assets/images/05.png',
    'SURPRISE': 'assets/images/06.png',
    'CONTEMPT': 'assets/images/07.png',
    'LOVE': 'assets/images/08.png',
    'ANTICIPATION': 'assets/images/09.png',
    'TRUST': 'assets/images/10.png',
    'NEUTRAL': 'assets/images/11.png',
  };

  static String getAssetPath(String emotionType) {
    return _emotionToAsset[emotionType.toUpperCase()] ??
        'assets/images/11.png'; // Default to NEUTRAL
  }

  static List<String> get emotionList => _emotionToAsset.keys.toList();
}
