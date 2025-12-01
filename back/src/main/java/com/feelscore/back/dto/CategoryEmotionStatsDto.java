package com.feelscore.back.dto;

import com.feelscore.back.entity.CategoryEmotionStats;
import com.feelscore.back.entity.EmotionType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.AccessLevel;

import java.util.List;

public class CategoryEmotionStatsDto {

    // --- 1. Repository Projection Interface (필수) ---

    /**
     * 리포지토리의 @Query 결과(SUM, GROUP BY 등)를 받는 DTO Projection Interface.
     * 필드 이름은 @Query의 AS 별칭과 일치해야 합니다.
     */
    public interface GlobalStatProjection {
        EmotionType getEmotionType();
        Long getTotalCount(); // SUM(count) 결과
        Long getTotalScore(); // SUM(totalScore) 결과
    }

    // --- 2. 카테고리별 통계 기본 응답 ---

    @Getter
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor
    @Builder
    public static class Response {
        private Long categoryId;
        private String categoryName;
        private EmotionType emotionType;
        private Long count; // 글 개수
        private Long totalScore; // 점수 총합
        private Double averageScore; // 평균 점수

        public static Response from(CategoryEmotionStats stats) {
            Double averageScore = stats.getCount() > 0
                    ? (double) stats.getTotalScore() / stats.getCount()
                    : 0.0;

            // Category 엔티티에 접근하여 ID와 Name을 가져와야 합니다. (Fetch Join 필요)
            return Response.builder()
                    .categoryId(stats.getCategory().getId())
                    .categoryName(stats.getCategory().getName())
                    .emotionType(stats.getEmotionType())
                    .count(stats.getCount())
                    .totalScore(stats.getTotalScore())
                    .averageScore(averageScore)
                    .build();
        }
    }

    // --- 3. 카테고리별 감정 순위 응답 ---

    @Getter
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor
    @Builder
    public static class RankingResponse {
        private Long categoryId;
        private String categoryName;
        private List<EmotionRank> emotionRanks; // 감정별 순위

        @Getter
        @NoArgsConstructor(access = AccessLevel.PROTECTED)
        @AllArgsConstructor
        @Builder
        public static class EmotionRank {
            private EmotionType emotionType;
            private Long totalScore;
            private Long count;
            private Double averageScore;
            private Integer rank; // 순위
        }
    }

    // --- 4. 전체 감정 순위 응답 (GlobalStatProjection 기반) ---

    @Getter
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor
    @Builder
    public static class GlobalRankingResponse {
        private EmotionType emotionType;
        private Long totalCount; // 전체 글 개수
        private Long totalScore; // 전체 점수 합
        private Double averageScore; // 전체 평균
        private Integer rank;

        public static GlobalRankingResponse of(EmotionType emotionType, Long totalCount, Long totalScore, Integer rank) {
            Double averageScore = totalCount > 0
                    ? (double) totalScore / totalCount
                    : 0.0;

            return GlobalRankingResponse.builder()
                    .emotionType(emotionType)
                    .totalCount(totalCount)
                    .totalScore(totalScore)
                    .averageScore(averageScore)
                    .rank(rank)
                    .build();
        }
    }

    // --- 5. 카테고리 우세 감정 응답 (메인 페이지용) ---

    @Getter
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor
    @Builder
    public static class DominantEmotionResponse {
        private Long categoryId;
        private String categoryName;
        private EmotionType dominantEmotion; // 가장 높은 감정
        private Long dominantScore; // 해당 감정의 총점
        private Long totalPostCount; // 전체 게시글 수

        public static DominantEmotionResponse of(Long categoryId, String categoryName,
                                                 EmotionType dominantEmotion, Long dominantScore,
                                                 Long totalPostCount) {
            return DominantEmotionResponse.builder()
                    .categoryId(categoryId)
                    .categoryName(categoryName)
                    .dominantEmotion(dominantEmotion)
                    .dominantScore(dominantScore)
                    .totalPostCount(totalPostCount)
                    .build();
        }
    }

    // --- 6. 감정별 카테고리 순위 (특정 감정이 강한 카테고리 찾기) ---

    @Getter
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor
    @Builder
    public static class EmotionByCategoryResponse {
        private EmotionType emotionType;
        private List<CategoryScore> categories;

        @Getter
        @NoArgsConstructor(access = AccessLevel.PROTECTED)
        @AllArgsConstructor
        @Builder
        public static class CategoryScore {
            private Long categoryId;
            private String categoryName;
            private Long totalScore;
            private Long count;
            private Double averageScore;
            private Integer rank;
        }
    }
}