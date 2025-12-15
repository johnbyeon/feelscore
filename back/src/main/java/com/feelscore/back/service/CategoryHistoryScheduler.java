package com.feelscore.back.service;

import com.feelscore.back.dto.CategoryStatsDto;
import com.feelscore.back.dto.StatsPeriod;
import com.feelscore.back.entity.Category;
import com.feelscore.back.entity.CategoryHistory;
import com.feelscore.back.repository.CategoryHistoryRepository;
import com.feelscore.back.repository.CategoryRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class CategoryHistoryScheduler {

    private final CategoryStatsService categoryStatsService;
    private final CategoryRepository categoryRepository;
    private final CategoryHistoryRepository categoryHistoryRepository;

    // Run every 6 hours: 00:00, 06:00, 12:00, 18:00
    @Scheduled(cron = "0 0 0,6,12,18 * * *")
    @Transactional
    public void snapshotCategoryStats() {
        log.info("Starting scheduled category stats snapshot...");

        // 1. Get current stats (ALL period)
        List<CategoryStatsDto> currentStats = categoryStatsService.getRealtimeStats(StatsPeriod.ALL);

        // 2. Save history for each category
        for (CategoryStatsDto stat : currentStats) {
            Category category = categoryRepository.findById(stat.getCategoryId())
                    .orElse(null);

            if (category != null) {
                CategoryHistory history = CategoryHistory.builder()
                        .category(category)
                        .score(stat.getScore())
                        .commentCount(stat.getCommentCount() != null ? stat.getCommentCount() : 0L)
                        .build();

                categoryHistoryRepository.save(history);
            }
        }

        log.info("Finished category stats snapshot. Saved {} records.", currentStats.size());
    }
}
