import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Mock Data
  final List<EmotionCategory> _categories = [
    EmotionCategory(
      name: 'Happiness',
      totalScore: 85,
      subCategories: [
        SubCategory(name: 'Joy', score: 90),
        SubCategory(name: 'Excitement', score: 80),
        SubCategory(name: 'Gratitude', score: 85),
      ],
    ),
    EmotionCategory(
      name: 'Sadness',
      totalScore: 30,
      subCategories: [
        SubCategory(name: 'Grief', score: 20),
        SubCategory(name: 'Loneliness', score: 40),
      ],
    ),
    EmotionCategory(
      name: 'Anxiety',
      totalScore: 45,
      subCategories: [
        SubCategory(name: 'Worry', score: 50),
        SubCategory(name: 'Stress', score: 40),
      ],
    ),
    EmotionCategory(
      name: 'Anger',
      totalScore: 20,
      subCategories: [
        SubCategory(name: 'Frustration', score: 30),
        SubCategory(name: 'Irritation', score: 10),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Search Bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search emotions...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
              ),
              const SizedBox(height: 20),
              // Category List
              Expanded(
                child: ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ExpansionTile(
                        shape: const Border(), // Remove default border
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              category.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getScoreColor(
                                  category.totalScore,
                                ).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${category.totalScore}',
                                style: TextStyle(
                                  color: _getScoreColor(category.totalScore),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        children: category.subCategories.map((sub) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  sub.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  '${sub.score}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
}

class EmotionCategory {
  final String name;
  final int totalScore;
  final List<SubCategory> subCategories;

  EmotionCategory({
    required this.name,
    required this.totalScore,
    required this.subCategories,
  });
}

class SubCategory {
  final String name;
  final int score;

  SubCategory({required this.name, required this.score});
}
