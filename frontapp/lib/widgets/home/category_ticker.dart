import 'dart:async';
import 'package:flutter/material.dart';
import '../../home_page.dart'; // For CategoryStat model
import '../../category_detail_page.dart';
import '../../utils/emotion_asset_helper.dart';

class CategoryTicker extends StatefulWidget {
  final List<CategoryStat> categories;

  const CategoryTicker({super.key, required this.categories});

  @override
  State<CategoryTicker> createState() => _CategoryTickerState();
}

class _CategoryTickerState extends State<CategoryTicker>
    with WidgetsBindingObserver {
  late PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  // Infinite scroll simulation large number
  static const int _infinitePageOffset = 1000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start in the middle to allow scrolling both ways if needed,
    // but principally to simulate infinite.
    _currentPage = _infinitePageOffset;
    _pageController = PageController(initialPage: _infinitePageOffset);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopAutoScroll();
    } else if (state == AppLifecycleState.resumed) {
      _startAutoScroll();
    }
  }

  void _stopAutoScroll() {
    _timer?.cancel();
    _timer = null;
  }

  void _startAutoScroll() {
    _stopAutoScroll();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      // Skip if not on current screen (e.g. pushed to detail or background not fully caught)
      if (ModalRoute.of(context)?.isCurrent == false) return;

      _currentPage++;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty) return const SizedBox.shrink();

    // Calculate effective item count for modulo logic
    // We display 2 items per page.
    // If odd number of categories, the last one might be paired with empty or wrap?
    // Let's simpler approach: Flatten the list indices.
    // Page 0: Cat 0, Cat 1
    // Page 1: Cat 2, Cat 3
    final categoryCount = widget.categories.length;
    // We want infinite pages.

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white10),
      ),
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics:
            const NeverScrollableScrollPhysics(), // Disable user scroll if auto-only desired? User might want to scroll? let's keep it auto mostly or allow manual. User didn't specify manual scroll. Auto usually implies no manual conflict. Set physics to Never? Or allow? Let's allow.
        // Actually, user said "continuously display... 6 hour unit... move up".
        // Let's allow manual scroll but it might fight timer.
        // For ticker usually it's auto.
        itemBuilder: (context, index) {
          // Calculate which categories to show on this 'page'
          // Each page has 2 items.
          // index is page index.
          final firstItemIndex = (index * 2) % categoryCount;
          final secondItemIndex = (index * 2 + 1) % categoryCount;

          final cat1 = widget.categories[firstItemIndex];
          // Handle case where cat2 might wrap around redundantly if count is odd?
          // The modulo handles wrapping perfectly. E.g. length 3.
          // Page 0: 0, 1
          // Page 1: 2, 0  <-- Wraps seamlessly
          final cat2 = widget.categories[secondItemIndex];

          return Row(
            children: [
              Expanded(child: _buildTickerItem(cat1)),
              Container(
                width: 1,
                height: 20,
                color: Colors.white10,
              ), // Separator
              Expanded(child: _buildTickerItem(cat2)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTickerItem(CategoryStat cat) {
    // 1. Trend Logic (Real Data)
    Widget trendWidget;
    if (cat.trend == 'UP') {
      trendWidget = const Icon(
        Icons.arrow_drop_up,
        color: Colors.redAccent,
        size: 24,
      );
    } else if (cat.trend == 'DOWN') {
      trendWidget = const Icon(
        Icons.arrow_drop_down,
        color: Colors.blueAccent,
        size: 24,
      );
    } else {
      // STABLE, NONE, or null -> Show '-'
      trendWidget = const Text(
        '-',
        style: TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => CategoryDetailPage(
                  categoryId: cat.categoryId,
                  categoryName: cat.name,
                ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Trend
            Container(
              width: 24,
              alignment: Alignment.center,
              child: trendWidget,
            ),
            const SizedBox(width: 4),

            // 2. Category Name
            Flexible(
              child: Text(
                cat.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),

            // 3. Dominant Emotion + Score
            if (cat.dominantEmotion != null) ...[
              Image.asset(
                EmotionAssetHelper.getAssetPath(cat.dominantEmotion!),
                width: 16,
                height: 16,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              '${cat.score}',
              style: const TextStyle(
                color: Colors.white, // Score is white/highlighted
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),

            const SizedBox(width: 12),

            // 4. Comment Count
            const Icon(Icons.chat_bubble_outline, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              '${cat.commentCount}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
