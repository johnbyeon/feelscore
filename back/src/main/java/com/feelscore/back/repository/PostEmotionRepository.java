package com.feelscore.back.repository;

import com.feelscore.back.entity.EmotionType;
import com.feelscore.back.entity.PostEmotion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PostEmotionRepository extends JpaRepository<PostEmotion, Long> {

        // 게시글 ID로 감정 분석 결과 조회
        Optional<PostEmotion> findByPost_Id(Long postId);

        // 분석 완료된 감정 데이터만 조회
        List<PostEmotion> findByIsAnalyzed(Boolean isAnalyzed);

        // 특정 감정이 우세한 게시글 조회
        List<PostEmotion> findByDominantEmotion(EmotionType emotionType);

        // 게시글과 감정 데이터 함께 조회 (Fetch Join)
        @Query("SELECT pe FROM PostEmotion pe JOIN FETCH pe.post WHERE pe.id = :id")
        Optional<PostEmotion> findByIdWithPost(@Param("id") Long id);

        // 특정 카테고리의 감정 분석 결과 조회
        @Query("SELECT pe FROM PostEmotion pe " +
                        "JOIN pe.post p " +
                        "WHERE p.category.id = :categoryId AND pe.isAnalyzed = true")
        List<PostEmotion> findAnalyzedByPostCategoryId(@Param("categoryId") Long categoryId);

        // 분석되지 않은 게시글 감정 데이터 조회 (생성일 기준 오름차순)
        List<PostEmotion> findByIsAnalyzedOrderByPost_CreatedAtAsc(Boolean isAnalyzed);

        // 게시글 존재 여부 확인
        boolean existsByPost_Id(Long postId);

        // [NEW] 기간별 카테고리 감정 점수 합계 (Recalculate)
        @Query("SELECT new com.feelscore.back.dto.EmotionSumDto(" +
                        "p.category.id, " +
                        "SUM(pe.scores.joyScore), " +
                        "SUM(pe.scores.sadnessScore), " +
                        "SUM(pe.scores.angerScore), " +
                        "SUM(pe.scores.fearScore), " +
                        "SUM(pe.scores.disgustScore), " +
                        "SUM(pe.scores.surpriseScore), " +
                        "SUM(pe.scores.contemptScore), " +
                        "SUM(pe.scores.loveScore), " +
                        "SUM(pe.scores.anticipationScore), " +
                        "SUM(pe.scores.trustScore), " +
                        "SUM(pe.scores.neutralScore) " +
                        ") " +
                        "FROM PostEmotion pe JOIN pe.post p " +
                        "WHERE p.createdAt >= :startDate AND pe.isAnalyzed = true AND p.status = com.feelscore.back.entity.PostStatus.NORMAL "
                        +
                        "GROUP BY p.category.id")
        List<com.feelscore.back.dto.EmotionSumDto> sumScoresByDate(
                        @Param("startDate") java.time.LocalDateTime startDate);

        // [NEW] 전체 기간 카테고리 감정 점수 합계
        @Query("SELECT new com.feelscore.back.dto.EmotionSumDto(" +
                        "p.category.id, " +
                        "SUM(pe.scores.joyScore), " +
                        "SUM(pe.scores.sadnessScore), " +
                        "SUM(pe.scores.angerScore), " +
                        "SUM(pe.scores.fearScore), " +
                        "SUM(pe.scores.disgustScore), " +
                        "SUM(pe.scores.surpriseScore), " +
                        "SUM(pe.scores.contemptScore), " +
                        "SUM(pe.scores.loveScore), " +
                        "SUM(pe.scores.anticipationScore), " +
                        "SUM(pe.scores.trustScore), " +
                        "SUM(pe.scores.neutralScore) " +
                        ") " +
                        "FROM PostEmotion pe JOIN pe.post p " +
                        "WHERE pe.isAnalyzed = true AND p.status = com.feelscore.back.entity.PostStatus.NORMAL " +
                        "GROUP BY p.category.id")
        List<com.feelscore.back.dto.EmotionSumDto> sumScoresAll();

        // [NEW] 특정 유저의 감정 점수 합계 (Personal Dashboard)
        @Query("SELECT new com.feelscore.back.dto.EmotionSumDto(" +
                        "p.users.id, " +
                        "SUM(pe.scores.joyScore), " +
                        "SUM(pe.scores.sadnessScore), " +
                        "SUM(pe.scores.angerScore), " +
                        "SUM(pe.scores.fearScore), " +
                        "SUM(pe.scores.disgustScore), " +
                        "SUM(pe.scores.surpriseScore), " +
                        "SUM(pe.scores.contemptScore), " +
                        "SUM(pe.scores.loveScore), " +
                        "SUM(pe.scores.anticipationScore), " +
                        "SUM(pe.scores.trustScore), " +
                        "SUM(pe.scores.neutralScore) " +
                        ") " +
                        "FROM PostEmotion pe JOIN pe.post p " +
                        "WHERE p.users.id = :userId AND pe.isAnalyzed = true AND p.status = com.feelscore.back.entity.PostStatus.NORMAL "
                        +
                        "GROUP BY p.users.id")
        Optional<com.feelscore.back.dto.EmotionSumDto> sumScoresByUserId(@Param("userId") Long userId);

        void deleteByPost(com.feelscore.back.entity.Post post);
}
