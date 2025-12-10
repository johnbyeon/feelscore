package com.feelscore.back.service;

import com.feelscore.back.entity.*;
import com.feelscore.back.repository.CategoryEmotionStatsRepository;
import com.feelscore.back.repository.PostEmotionRepository;
import com.feelscore.back.repository.PostRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.NoSuchElementException;

@Slf4j
@Service
@RequiredArgsConstructor
public class CategoryStatsService {

    private final PostRepository postRepository;
    private final PostEmotionRepository postEmotionRepository;
    private final CategoryEmotionStatsRepository categoryEmotionStatsRepository;
    private final com.feelscore.back.repository.CategoryRepository categoryRepository;

    @Transactional
    public void updateStats(Long postId) {
        log.info("Updating category stats for Post ID: {}", postId);

        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new NoSuchElementException("Post not found: " + postId));

        PostEmotion postEmotion = postEmotionRepository.findByPost_Id(postId)
                .orElseThrow(() -> new NoSuchElementException("PostEmotion not found for Post ID: " + postId));

        Category category = post.getCategory();
        EmotionScores scores = postEmotion.getScores();

        log.info("Category: {}, Scores: {}", category.getName(), scores);

        // 모든 감정 타입에 대해 점수 업데이트 (재귀적)
        for (EmotionType type : EmotionType.values()) {
            Integer score = scores.getScoreByType(type);
            if (score > 0) {
                log.info("Updating stats for Type: {}, Score: {}", type, score);
                updateCategoryStatRecursive(category, type, score);
            }
        }
    }

    private void updateCategoryStatRecursive(Category category, EmotionType type, Integer score) {
        if (category == null)
            return;

        CategoryEmotionStats stats = categoryEmotionStatsRepository.findByCategoryAndEmotionType(category, type)
                .orElseGet(() -> CategoryEmotionStats.builder()
                        .category(category)
                        .emotionType(type)
                        .build());

        stats.addScore(score);
        categoryEmotionStatsRepository.save(stats);

        // 부모 카테고리로 재귀 호출
        updateCategoryStatRecursive(category.getParent(), type, score);
    }

    @Transactional
    public void updateUserReactionStats(Category category, EmotionType type, boolean isAddition) {
        // User Reaction Weight: 100 (Strongest confidence)
        final int REACTION_WEIGHT = 100;
        updateUserReactionRecursive(category, type, isAddition, REACTION_WEIGHT);
    }

    private void updateUserReactionRecursive(Category category, EmotionType type, boolean isAddition, int score) {
        if (category == null)
            return;

        CategoryEmotionStats stats = categoryEmotionStatsRepository.findByCategoryAndEmotionType(category, type)
                .orElseGet(() -> CategoryEmotionStats.builder()
                        .category(category)
                        .emotionType(type)
                        .build());

        if (isAddition) {
            stats.addScore(score);
        } else {
            stats.subtractScore(score);
        }
        categoryEmotionStatsRepository.save(stats);

        // Recurse to parent
        updateUserReactionRecursive(category.getParent(), type, isAddition, score);
    }

    @Transactional(readOnly = true)
    public java.util.List<com.feelscore.back.dto.CategoryStatsDto> getRealtimeStats(
            com.feelscore.back.dto.StatsPeriod period) {
        // 1. 기간에 따른 통계 데이터 조회
        java.time.LocalDateTime startDate;
        java.util.List<com.feelscore.back.dto.EmotionSumDto> rawSums;

        if (period == com.feelscore.back.dto.StatsPeriod.ALL) {
            rawSums = postEmotionRepository.sumScoresAll();
        } else {
            java.time.LocalDateTime now = java.time.LocalDateTime.now();
            switch (period) {
                case MONTH:
                    startDate = now.minusDays(30);
                    break;
                case WEEK:
                    startDate = now.minusDays(7);
                    break;
                case DAY:
                    startDate = now.minusDays(1);
                    break;
                default:
                    startDate = now.minusYears(100);
            }
            rawSums = postEmotionRepository.sumScoresByDate(startDate);
        }

        // 2. 결과를 Map으로 변환 (CategoryId -> EmotionMap)
        // 각 카테고리별 자신의 직접적인 점수
        java.util.Map<Long, java.util.Map<EmotionType, Long>> selfScoreMap = new java.util.HashMap<>();
        for (com.feelscore.back.dto.EmotionSumDto dto : rawSums) {
            selfScoreMap.put(dto.getId(), dto.toMap());
        }

        // 3. 최상위 카테고리 로드 및 트리 구성
        java.util.List<Category> rootCategories = categoryRepository.findByDepth(1);

        return rootCategories.stream()
                .map(root -> buildStatsRecursive(root, selfScoreMap).dto)
                .sorted(java.util.Comparator.comparingLong(com.feelscore.back.dto.CategoryStatsDto::getScore)
                        .reversed())
                .collect(java.util.stream.Collectors.toList());
    }

    @lombok.AllArgsConstructor
    private static class StatsResult {
        com.feelscore.back.dto.CategoryStatsDto dto;
        java.util.Map<EmotionType, Long> accumulatedScores;
    }

    private StatsResult buildStatsRecursive(Category category,
            java.util.Map<Long, java.util.Map<EmotionType, Long>> selfScoreMap) {
        // 1. 내 점수
        java.util.Map<EmotionType, Long> myScores = new java.util.HashMap<>(
                selfScoreMap.getOrDefault(category.getId(), new java.util.HashMap<>()));
        for (EmotionType type : EmotionType.values()) {
            myScores.putIfAbsent(type, 0L);
        }

        // 2. 자식 순회
        java.util.List<com.feelscore.back.dto.CategoryStatsDto> childrenDtos = new java.util.ArrayList<>();

        for (Category child : category.getChildren()) {
            StatsResult childResult = buildStatsRecursive(child, selfScoreMap);
            childrenDtos.add(childResult.dto);

            // 자식 점수 누적
            for (java.util.Map.Entry<EmotionType, Long> entry : childResult.accumulatedScores.entrySet()) {
                myScores.put(entry.getKey(), myScores.get(entry.getKey()) + entry.getValue());
            }
        }

        // 자식들도 점수순 정렬
        childrenDtos
                .sort(java.util.Comparator.comparingLong(com.feelscore.back.dto.CategoryStatsDto::getScore).reversed());

        // 3. Dominant Emotion 계산 (NEUTRAL 제외)
        EmotionType dominant = null;
        long maxScore = 0;
        long totalScore = 0;

        for (java.util.Map.Entry<EmotionType, Long> entry : myScores.entrySet()) {
            // 총점 계산 (모든 감정 포함? 아니면 특정 감정만? 보통 다 포함)
            totalScore += entry.getValue();

            // Dominant 계산 (NEUTRAL 제외)
            if (entry.getKey() != EmotionType.NEUTRAL) {
                if (entry.getValue() > maxScore) {
                    maxScore = entry.getValue();
                    dominant = entry.getKey();
                }
            }
        }

        // 만약 모든 점수가 0이거나 NEUTRAL만 있으면 null 또는 처리
        if (maxScore <= 0 && dominant == null) {
            // 예: Neutral만 있거나 점수가 아예 없음
            // 그대로 null
        }

        com.feelscore.back.dto.CategoryStatsDto dto = com.feelscore.back.dto.CategoryStatsDto.builder()
                .categoryId(category.getId())
                .name(category.getName())
                .dominantEmotion(dominant)
                .score(maxScore) // Use maxScore (score of the dominant emotion) instead of totalScore
                .children(childrenDtos)
                .build();

        return new StatsResult(dto, myScores);
    }
}
