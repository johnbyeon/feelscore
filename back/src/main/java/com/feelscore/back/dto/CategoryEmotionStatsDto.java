package com.feelscore.back.dto;

import com.feelscore.back.entity.CategoryEmotionStats;
import com.feelscore.back.entity.EmotionType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.List;
import java.util.stream.Collectors;

public class CategoryEmotionStatsDto {

    // 카테고리별 감정 통계 응답
    @Getter
    @NoArgsConstructor
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

    // 카테고리별 감정 순위 응답
    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class RankingResponse {
        private Long categoryId;
        private String categoryName;
        private List<EmotionRank> emotionRanks; // 감정별 순위

        @Getter
        @NoArgsConstructor
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

    // 전체 감정 순위 응답 (카테고리 무관)
    @Getter
    @NoArgsConstructor
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

    // 카테고리 우세 감정 응답 (메인 페이지용)
    @Getter
    @NoArgsConstructor
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

    // 감정별 카테고리 순위 (특정 감정이 강한 카테고리 찾기)
    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class EmotionByCategoryResponse {
        private EmotionType emotionType;
        private List<CategoryScore> categories;

        @Getter
        @NoArgsConstructor
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