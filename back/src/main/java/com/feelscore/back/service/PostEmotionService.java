package com.feelscore.back.service;

import com.feelscore.back.entity.*;
import com.feelscore.back.repository.CategoryEmotionStatsRepository;
import com.feelscore.back.repository.PostEmotionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class PostEmotionService {

    private final PostEmotionRepository postEmotionRepository;
    private final CategoryEmotionStatsRepository statsRepository;

    // --- 0. 게시글 감정 분석 결과 조회 ---

    /**
     * 특정 게시글 ID를 기반으로 PostEmotion 데이터를 조회합니다.
     * @param postId 조회 대상 게시글 ID
     * @return 조회된 PostEmotion 엔티티
     * @throws IllegalArgumentException PostEmotion 데이터가 없을 경우 발생
     */
    @Transactional(readOnly = true) // ⬅️ 조회 전용이므로 readOnly=true
    public PostEmotion getEmotionAnalysisByPostId(Long postId) {

        // Repository의 findByPost_Id를 사용하여 조회합니다.
        return postEmotionRepository.findByPost_Id(postId)
                .orElseThrow(() -> new IllegalArgumentException("해당 게시글의 감정 분석 데이터를 찾을 수 없습니다."));
    }

    // --- 1. 감정 분석 결과 저장 및 통계 반영 (최초 생성 시) ---

    @Transactional
    public PostEmotion saveAndApplyAnalysis(Post post, EmotionScores scores, EmotionType dominantEmotion) {
        // ... (기존 saveAndApplyAnalysis 로직)
        PostEmotion postEmotion = PostEmotion.builder()
                .post(post)
                .scores(scores)
                .dominantEmotion(dominantEmotion)
                .build();

        postEmotion.markAsAnalyzed();
        postEmotion = postEmotionRepository.save(postEmotion);

        applyScoreToCategoryStats(post.getCategory(), scores);

        return postEmotion;
    }

    // --- 2. 감정 분석 결과 재분석 및 통계 반영 (업데이트 시) ---

    @Transactional
    public PostEmotion reAnalyzeAndApplyStats(Long postId, EmotionScores newScores, EmotionType dominantEmotion) {
        // ... (기존 reAnalyzeAndApplyStats 로직)
        PostEmotion postEmotion = postEmotionRepository.findByPost_Id(postId)
                .orElseThrow(() -> new IllegalArgumentException("분석 대상 게시글 감정 데이터를 찾을 수 없습니다."));

        Category category = postEmotion.getPost().getCategory();

        EmotionScores oldScores = postEmotion.getScores();
        revertScoreFromCategoryStats(category, oldScores); // 이전 점수 차감

        postEmotion.updateAnalysis(newScores, dominantEmotion);

        applyScoreToCategoryStats(category, newScores); // 새 점수 추가

        return postEmotion;
    }

    // --- 3. 감정 분석 결과 삭제 및 통계 반영 (삭제 시) ---

    /**
     * 게시글이 삭제될 때 해당 감정 분석 결과를 삭제하고 통계를 되돌립니다.
     * 이 메서드는 Post 엔티티를 삭제하는 서비스에서 호출되어야 합니다.
     * @param postId 삭제 대상 게시글 ID
     */
    @Transactional
    public void deleteAnalysisAndRevertStats(Long postId) {

        // 1. 기존 PostEmotion 데이터 조회
        PostEmotion postEmotion = postEmotionRepository.findByPost_Id(postId)
                .orElseThrow(() -> new IllegalArgumentException("삭제 대상 게시글 감정 데이터를 찾을 수 없습니다."));

        Category category = postEmotion.getPost().getCategory();
        EmotionScores scores = postEmotion.getScores();

        // 2. 통계에서 점수 차감 (Revert)
        // ⬅️ 핵심: 기존 로직 재활용
        revertScoreFromCategoryStats(category, scores);

        // 3. PostEmotion 엔티티 삭제
        postEmotionRepository.delete(postEmotion);
    }

    // --- 통계 처리 Private 메서드 ---

    private void applyScoreToCategoryStats(Category category, EmotionScores scores) {
        for (EmotionType type : EmotionType.values()) {
            Integer score = scores.getScoreByType(type);
            if (score == 0) continue;

            CategoryEmotionStats stats = statsRepository.findByCategory_IdAndEmotionType(category.getId(), type)
                    .orElseGet(() ->
                            CategoryEmotionStats.builder()
                                    .category(category)
                                    .emotionType(type)
                                    .build()
                    );

            stats.addScore(score);

            if (stats.getId() == null) {
                statsRepository.save(stats);
            }
        }
    }

    private void revertScoreFromCategoryStats(Category category, EmotionScores scores) {
        for (EmotionType type : EmotionType.values()) {
            Integer score = scores.getScoreByType(type);
            if (score == 0) continue;

            CategoryEmotionStats stats = statsRepository.findByCategory_IdAndEmotionType(category.getId(), type)
                    .orElseThrow(() -> new IllegalStateException("이전 통계 데이터를 찾을 수 없습니다. (데이터 불일치)"));

            stats.subtractScore(score);
            // 기존 엔티티는 @Transactional에 의해 자동 업데이트됩니다.
        }
    }
}