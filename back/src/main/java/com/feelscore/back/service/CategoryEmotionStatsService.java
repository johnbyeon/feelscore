package com.feelscore.back.service;

import com.feelscore.back.dto.CategoryEmotionStatsDto;
import com.feelscore.back.dto.CategoryEmotionStatsDto.GlobalStatProjection;
import com.feelscore.back.entity.*;
import com.feelscore.back.exception.NotFoundException;
import com.feelscore.back.repository.CategoryEmotionStatsRepository;
import com.feelscore.back.repository.CategoryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true) // ✅ 조회 전용 서비스이므로 기본적으로 readOnly = true
public class CategoryEmotionStatsService {

    private final CategoryEmotionStatsRepository statsRepository;
    private final CategoryRepository categoryRepository;


    // 이전에 구현된 PostEmotionService의 통계 로직을 가져왔음을 가정합니다.

    // --- 통계 업데이트 로직 (PostEmotionService에서 호출) ---

    // 🚨 주의: 이 메서드는 쓰기 트랜잭션을 위해 PostEmotionService에서 호출되어야 함.
    // PostEmotionService 내부에서 이 로직을 재활용한 경우를 가정하고 수정합니다.
    @Transactional
    public void updateStats(PostEmotion postEmotion) {
        Long categoryId = postEmotion.getPost().getCategory().getId();
        Category category = postEmotion.getPost().getCategory();

        // 🚨 수정: PostEmotion에서 EmotionScores 객체를 가져옵니다.
        EmotionScores scores = postEmotion.getScores();

        // 1. 해당 카테고리의 기존 통계를 한 번에 조회하여 Map에 캐싱 (N+1 방지)
        Map<EmotionType, CategoryEmotionStats> statsMap = statsRepository.findByCategory_Id(categoryId)
                .stream()
                .collect(Collectors.toMap(
                        CategoryEmotionStats::getEmotionType,
                        stats -> stats
                ));

        // 2. EmotionScores를 순회하며 메모리에서 통계 업데이트
        for (EmotionType type : EmotionType.values()) {
            // 🚨 수정: EmotionScores의 getScoreByType 메서드를 사용합니다.
            Integer score = scores.getScoreByType(type);

            updateEmotionStatInMemory(statsMap, category, type, score);
        }

        // 3. 변경된 것들만 한 번에 저장 (새로 생성된 엔티티 포함)
        statsRepository.saveAll(statsMap.values());
    }

    // 메모리에서 통계 업데이트 (내부 헬퍼 메서드)
    private void updateEmotionStatInMemory(Map<EmotionType, CategoryEmotionStats> statsMap,
                                           Category category, EmotionType emotionType, Integer score) {
        if (score == null || score == 0) {
            return;
        }

        // 키가 없으면 빌더를 통해 새 통계 엔티티 생성 후 Map에 추가
        CategoryEmotionStats stats = statsMap.computeIfAbsent(emotionType, type ->
                CategoryEmotionStats.builder()
                        .category(category)
                        .emotionType(type)
                        .build()
        );

        stats.addScore(score);
    }

    // --- 통계 조회 로직 (Projection DTO 활용 및 성능 개선) ---

    // 특정 카테고리의 감정 순위 조회 (점수 높은 순)
    // * Category 엔티티 조회 (NotFoundException 확인 포함) 로직은 findCategoryById 헬퍼 메서드 사용

    // 전체 감정 순위 조회 (카테고리 무관, count 기준)
    public List<CategoryEmotionStatsDto.GlobalRankingResponse> getGlobalEmotionRankingByCount() {
        // 🚨 수정: 리포지토리에서 GlobalStatProjection DTO를 바로 반환하도록 변경 (List<Object[]> 대신)
        // 리포지토리 쿼리가 TotalCount와 TotalScore를 모두 SUM하도록 수정되었음을 가정합니다.
        List<GlobalStatProjection> results = statsRepository.getEmotionRankingByCountProjection();

        List<CategoryEmotionStatsDto.GlobalRankingResponse> rankings = new ArrayList<>();
        for (int i = 0; i < results.size(); i++) {
            GlobalStatProjection row = results.get(i);

            // 🚨 수정: 루프 내부에서 추가적인 DB 조회 (getTotalScoreByEmotion) 제거
            // 모든 정보가 이미 Projection에 담겨 있습니다.
            rankings.add(CategoryEmotionStatsDto.GlobalRankingResponse.of(
                    row.getEmotionType(),
                    row.getTotalCount(),
                    row.getTotalScore(),
                    i + 1 // 순위
            ));
        }

        return rankings;
    }

    // 전체 감정 순위 조회 (카테고리 무관, score 기준)
    public List<CategoryEmotionStatsDto.GlobalRankingResponse> getGlobalEmotionRankingByScore() {
        // 🚨 수정: 리포지토리에서 GlobalStatProjection DTO를 바로 반환하도록 변경
        // 리포지토리 쿼리가 TotalCount와 TotalScore를 모두 SUM하도록 수정되었음을 가정합니다.
        List<GlobalStatProjection> results = statsRepository.getEmotionRankingByScoreProjection();

        List<CategoryEmotionStatsDto.GlobalRankingResponse> rankings = new ArrayList<>();
        for (int i = 0; i < results.size(); i++) {
            GlobalStatProjection row = results.get(i);

            // 🚨 수정: 루프 내부에서 추가적인 DB 조회 (findByEmotionType) 제거
            rankings.add(CategoryEmotionStatsDto.GlobalRankingResponse.of(
                    row.getEmotionType(),
                    row.getTotalCount(),
                    row.getTotalScore(),
                    i + 1 // 순위
            ));
        }

        return rankings;
    }
    // 🌟 추가할 메서드: 특정 카테고리 내 감정 순위 조회 (점수 높은 순)
    /**
     * 특정 카테고리의 모든 감정 통계를 조회하고, 점수 총합을 기준으로 순위를 매겨 DTO로 변환합니다.
     * @param categoryId 대상 카테고리 ID
     * @return CategoryEmotionStatsDto.RankingResponse (순위가 매겨진 DTO)
     */

    @Transactional(readOnly = true)
    public CategoryEmotionStatsDto.RankingResponse getCategoryEmotionRanking(Long categoryId) {

        // 1. 카테고리 엔티티 조회 (NotFoundException 검증 포함)
        Category category = findCategoryById(categoryId);

        // 2. 리포지토리 호출: 특정 카테고리의 통계를 점수 높은 순으로 조회
        List<CategoryEmotionStats> statsList = statsRepository
                .findByCategory_IdOrderByTotalScoreDesc(categoryId);

        // 3. 순위 매기기 및 DTO 변환
        List<CategoryEmotionStatsDto.RankingResponse.EmotionRank> emotionRanks = new ArrayList<>();

        for (int i = 0; i < statsList.size(); i++) {
            CategoryEmotionStats stats = statsList.get(i);

            // 평균 점수 계산 로직
            Double avgScore = stats.getCount() > 0
                    ? (double) stats.getTotalScore() / stats.getCount()
                    : 0.0;

            // EmotionRank DTO 생성 및 추가
            emotionRanks.add(CategoryEmotionStatsDto.RankingResponse.EmotionRank.builder()
                    .emotionType(stats.getEmotionType())
                    .totalScore(stats.getTotalScore())
                    .count(stats.getCount())
                    .averageScore(avgScore)
                    .rank(i + 1) // 1부터 순위 매기기
                    .build());
        }

        // 4. 최종 RankingResponse DTO 생성 및 반환
        return CategoryEmotionStatsDto.RankingResponse.builder()
                .categoryId(category.getId())
                .categoryName(category.getName())
                .emotionRanks(emotionRanks)
                .build();
    }
    private Category findCategoryById(Long categoryId) {
        // categoryRepository는 이미 final 필드로 주입되어 있습니다.
        return categoryRepository.findById(categoryId)
                .orElseThrow(() -> new NotFoundException("존재하지 않는 카테고리입니다."));
    }

    // ... (나머지 조회 메서드들 - getStatsByCategory, getCategoryEmotionRanking 등은 DTO 변환만 하므로 유지)
    // ... (Private 헬퍼 메서드 - findCategoryById)
}