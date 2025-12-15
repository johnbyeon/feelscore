import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../utils/emotion_asset_helper.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';

class EmotionCalendar extends StatefulWidget {
  final String userId;

  const EmotionCalendar({super.key, required this.userId});

  @override
  State<EmotionCalendar> createState() => _EmotionCalendarState();
}

class _EmotionCalendarState extends State<EmotionCalendar> {
  final ApiService _apiService = ApiService();
  String _selectedMode =
      '월간'; // Default to Monthly as per typical calendar usage
  DateTime _focusedDate = DateTime.now();
  Map<String, String> _emotionHistory = {}; // "YYYY-MM-DD" -> "JOY"
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  void _fetchHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      DateTime start, end;
      if (_selectedMode == '주간') {
        // Find Sunday of current week
        start = _focusedDate.subtract(Duration(days: _focusedDate.weekday % 7));
        end = start.add(const Duration(days: 6));
      } else {
        // Default fallback (should be Monthly or Weekly)
        start = DateTime(_focusedDate.year, _focusedDate.month, 1);
        end = DateTime(_focusedDate.year, _focusedDate.month + 1, 0);
      }

      final startStr = DateFormat('yyyy-MM-dd').format(start);
      final endStr = DateFormat('yyyy-MM-dd').format(end);

      final data = await _apiService.getEmotionHistory(startStr, endStr);

      final Map<String, String> history = {};
      for (var item in data) {
        // item: { "date": "2024-05-20", "emotion": "JOY" }
        if (item['date'] != null && item['emotion'] != null) {
          history[item['date']] = item['emotion'];
        }
      }

      setState(() {
        _emotionHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      // print('Error fetching history: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onModeChanged(String mode) {
    setState(() {
      _selectedMode = mode;
      _focusedDate = DateTime.now(); // Reset to today when switching modes
    });
    _fetchHistory();
  }

  void _changePage(int offset) {
    setState(() {
      if (_selectedMode == '주간') {
        _focusedDate = _focusedDate.add(Duration(days: offset * 7));
      } else if (_selectedMode == '월간') {
        _focusedDate = DateTime(
          _focusedDate.year,
          _focusedDate.month + offset,
          1,
        );
      }
    });
    _fetchHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900], // Dark background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Toggles + Date Nav
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Toggles
              Row(
                children: [
                  _buildToggle('주간'),
                  const SizedBox(width: 12),
                  _buildToggle('월간'),
                ],
              ),
              // Date Nav (Arrows)
              Row(
                children: [
                  if (_selectedMode == '월간')
                    Text(
                      DateFormat('MM').format(_focusedDate), // Month number
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                  IconButton(
                    icon: const Icon(Icons.arrow_left, color: Colors.white),
                    onPressed: () => _changePage(-1),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  // If Monthly, maybe show Year? Or just simple arrows.
                  // Implementation choice: Simple arrows like screenshot.
                  if (_selectedMode == '월간')
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.white,
                    ),
                  IconButton(
                    icon: const Icon(Icons.arrow_right, color: Colors.white),
                    onPressed: () => _changePage(1),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Content
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_selectedMode == '주간')
            _buildWeeklyView()
          else
            _buildMonthlyView(),
        ],
      ),
    );
  }

  Widget _buildToggle(String mode) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () => _onModeChanged(mode),
      child: Text(
        mode,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[600],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildWeeklyView() {
    // Determine start of week (Sunday)
    final startOfWeek = _focusedDate.subtract(
      Duration(days: _focusedDate.weekday % 7),
    );
    final weekDays = ['일', '월', '화', '수', '목', '금', '토']; // Sun to Sat

    return Column(
      children: [
        // Days Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(7, (index) {
            final isToday = _isSameDay(
              startOfWeek.add(Duration(days: index)),
              DateTime.now(),
            );
            return Text(
              weekDays[index],
              style: TextStyle(
                color: isToday ? Colors.redAccent : Colors.grey[500],
                fontWeight: FontWeight.bold,
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        const Divider(color: Colors.grey, height: 1),
        const SizedBox(height: 8),
        // Dates & Emotions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(7, (index) {
            final date = startOfWeek.add(Duration(days: index));
            final dateStr = DateFormat('yyyy-MM-dd').format(date);
            final emotion = _getEmotionOrNeutral(dateStr, date);
            final isToday = _isSameDay(date, DateTime.now());

            return Column(
              children: [
                Text(
                  DateFormat('d').format(date),
                  style: TextStyle(
                    color: isToday ? Colors.redAccent : Colors.white,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 8),
                if (emotion != null)
                  Image.asset(
                    EmotionAssetHelper.getAssetPath(emotion),
                    width: 24,
                    height: 24,
                  )
                else
                  const SizedBox(width: 24, height: 24), // Placeholder
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildMonthlyView() {
    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedDate.year,
      _focusedDate.month,
    );
    final firstDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final firstWeekday = firstDayOfMonth.weekday % 7; // Sunday=0, Monday=1...

    // Grid 7 columns
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: daysInMonth + firstWeekday,
      itemBuilder: (context, index) {
        if (index < firstWeekday) {
          return const SizedBox.shrink();
        }
        final day = index - firstWeekday + 1;
        final date = DateTime(_focusedDate.year, _focusedDate.month, day);
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final emotion = _getEmotionOrNeutral(dateStr, date);
        final isToday = _isSameDay(date, DateTime.now());

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$day',
              style: TextStyle(
                color: isToday ? Colors.redAccent : Colors.grey[400],
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            if (emotion != null)
              Expanded(
                child: Image.asset(
                  EmotionAssetHelper.getAssetPath(emotion),
                  fit: BoxFit.contain,
                ),
              )
            else
              const Spacer(),
          ],
        );
      },
    );
  }

  String? _getEmotionOrNeutral(String dateStr, DateTime date) {
    // 1. If today and current user, check UserProvider first
    if (_isSameDay(date, DateTime.now())) {
      final userProvider = context.watch<UserProvider>();
      if (userProvider.userId == widget.userId &&
          userProvider.todayEmotion != null) {
        return userProvider.todayEmotion;
      }
    }

    if (_emotionHistory.containsKey(dateStr)) {
      return _emotionHistory[dateStr];
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final checkDate = DateTime(date.year, date.month, date.day);

    if (!checkDate.isAfter(today)) {
      return 'NEUTRAL';
    }
    return null;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
