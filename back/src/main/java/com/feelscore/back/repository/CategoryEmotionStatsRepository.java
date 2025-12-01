package com.feelscore.back.repository;

import com.feelscore.back.dto.CategoryEmotionStatsDto.GlobalStatProjection;
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

    // --- 기본 조회 메서드 ---
    List<CategoryEmotionStats> findByCategory_Id(Long categoryId);
    Optional<CategoryEmotionStats> findByCategory_IdAndEmotionType(Long categoryId, EmotionType emotionType);
    List<CategoryEmotionStats> findByEmotionType(EmotionType emotionType);
    List<CategoryEmotionStats> findByCategory_IdOrderByTotalScoreDesc(Long categoryId);
    boolean existsByCategory_IdAndEmotionType(Long categoryId, EmotionType emotionType);

    // --- 통계 쿼리 ---

    @Query("SELECT SUM(ces.totalScore) FROM CategoryEmotionStats ces WHERE ces.emotionType = :emotionType")
    Long getTotalScoreByEmotion(@Param("emotionType") EmotionType emotionType);

    @Query("SELECT ces.emotionType, AVG( (1.0 * ces.totalScore) / ces.count ) " +
            "FROM CategoryEmotionStats ces " +
            "WHERE ces.category.id = :categoryId AND ces.count > 0 " +
            "GROUP BY ces.emotionType")
    List<Object[]> getAverageScoresByCategory(@Param("categoryId") Long categoryId);

    // --- 🌟 핵심: Projection을 사용하는 랭킹 쿼리 (이것만 남겨야 함) ---

    @Query(value = "SELECT ces.emotionType AS emotionType, " +
            "SUM(ces.count) AS totalCount, " +
            "SUM(ces.totalScore) AS totalScore " +
            "FROM CategoryEmotionStats ces " +
            "GROUP BY ces.emotionType " +
            "ORDER BY totalCount DESC")
    List<GlobalStatProjection> getEmotionRankingByCountProjection(); // ✅ 이름에 Projection 포함

    @Query(value = "SELECT ces.emotionType AS emotionType, " +
            "SUM(ces.count) AS totalCount, " +
            "SUM(ces.totalScore) AS totalScore " +
            "FROM CategoryEmotionStats ces " +
            "GROUP BY ces.emotionType " +
            "ORDER BY totalScore DESC")
    List<GlobalStatProjection> getEmotionRankingByScoreProjection(); // ✅ 이름에 Projection 포함

    // 🚨 주의: getEmotionRankingByCount() 같은 @Query 없는 구버전 메서드는 모두 지워야 합니다!
}