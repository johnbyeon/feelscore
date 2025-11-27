package com.feelscore.back.repository;

import com.feelscore.back.entity.CategoryEmotionStats;
import com.feelscore.back.entity.EmotionType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CategoryEmotionStatsRepository extends JpaRepository<CategoryEmotionStats, Long> {

    // 특정 카테고리의 모든 감정 통계 조회
    List<CategoryEmotionStats> findByCategory_Id(Long categoryId);

    // 특정 카테고리의 특정 감정 통계 조회
    Optional<CategoryEmotionStats> findByCategory_IdAndEmotionType(Long categoryId, EmotionType emotionType);

    // 특정 감정의 모든 카테고리 통계 조회
    List<CategoryEmotionStats> findByEmotionType(EmotionType emotionType);

    // 특정 카테고리에서 점수 높은 순으로 감정 조회
    List<CategoryEmotionStats> findByCategory_IdOrderByTotalScoreDesc(Long categoryId);

    // 전체 카테고리에서 특정 감정의 총합 조회
    @Query("SELECT SUM(ces.totalScore) FROM CategoryEmotionStats ces " +
            "WHERE ces.emotionType = :emotionType")
    Long getTotalScoreByEmotion(@Param("emotionType") EmotionType emotionType);

    // 특정 카테고리의 감정별 평균 점수 조회
    @Query("SELECT ces.emotionType, AVG( (1.0 * ces.totalScore) / ces.count ) " +
            "FROM CategoryEmotionStats ces " +
            "WHERE ces.category.id = :categoryId AND ces.count > 0 " +
            "GROUP BY ces.emotionType")
    List<Object[]> getAverageScoresByCategory(@Param("categoryId") Long categoryId);

    // 가장 활발한 감정 순위 조회 (전체 카테고리, count 기준)
    @Query("SELECT ces.emotionType, SUM(ces.count) as totalCount " +
            "FROM CategoryEmotionStats ces " +
            "GROUP BY ces.emotionType " +
            "ORDER BY totalCount DESC")
    List<Object[]> getEmotionRankingByCount();

    // 가장 높은 점수의 감정 순위 조회 (전체 카테고리, totalScore 기준)
    @Query("SELECT ces.emotionType, SUM(ces.totalScore) as totalScore " +
            "FROM CategoryEmotionStats ces " +
            "GROUP BY ces.emotionType " +
            "ORDER BY totalScore DESC")
    List<Object[]> getEmotionRankingByScore();

    // 통계 존재 여부 확인
    boolean existsByCategory_IdAndEmotionType(Long categoryId, EmotionType emotionType);
}
