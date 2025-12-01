package com.feelscore.back.service;

import com.feelscore.back.entity.*;
import com.feelscore.back.repository.CategoryEmotionStatsRepository;
import com.feelscore.back.repository.PostEmotionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class PostEmotionServiceTest {

    @InjectMocks
    private PostEmotionService postEmotionService;

    @Mock
    private PostEmotionRepository postEmotionRepository;
    @Mock
    private CategoryEmotionStatsRepository statsRepository;

    private Post mockPost;
    private Category mockCategory;
    private PostEmotion mockPostEmotion;
    private CategoryEmotionStats mockStats;
    private PostEmotion mockSavedPostEmotion;

    @BeforeEach
    void setUp() {
        mockCategory = mock(Category.class);
        mockPost = mock(Post.class);
        mockPostEmotion = mock(PostEmotion.class);
        mockStats = mock(CategoryEmotionStats.class);
        mockSavedPostEmotion = mock(PostEmotion.class);

        // 🚨 수정: lenient()를 붙여서, 이 설정이 사용되지 않는 테스트에서도 에러가 나지 않도록 함
        lenient().when(mockPostEmotion.getPost()).thenReturn(mockPost);
        lenient().when(mockPost.getCategory()).thenReturn(mockCategory);
        lenient().when(mockCategory.getId()).thenReturn(1L);

        // 🚨 수정: save 테스트에서 더 이상 사용하지 않는 mockSavedPostEmotion 설정은 제거함
        // (불필요한 stubbing 제거)
    }

    // --- 1. 재분석 (수정) 테스트 ---
    @Test
    @DisplayName("게시글 재분석 시 기존 통계 차감 및 새 통계 추가가 순서대로 이루어져야 한다")
    void reAnalyzeAndApplyStats_shouldRevertAndApplyScores() {
        // Given
        Long postId = 1L;
        EmotionScores oldScores = EmotionScores.builder().joyScore(50).build();
        // lenient() 덕분에 여기서만 사용되는 설정도 문제 없이 작동함
        when(mockPostEmotion.getScores()).thenReturn(oldScores);

        EmotionScores newScores = EmotionScores.builder().angerScore(80).build();
        EmotionType newDominant = EmotionType.ANGER;

        when(postEmotionRepository.findByPost_Id(postId)).thenReturn(Optional.of(mockPostEmotion));
        when(statsRepository.findByCategory_IdAndEmotionType(any(), eq(EmotionType.JOY)))
                .thenReturn(Optional.of(mockStats));
        when(statsRepository.findByCategory_IdAndEmotionType(any(), eq(EmotionType.ANGER)))
                .thenReturn(Optional.of(mockStats));

        // When
        postEmotionService.reAnalyzeAndApplyStats(postId, newScores, newDominant);

        // Then
        verify(mockStats, times(1)).subtractScore(50);
        verify(mockPostEmotion, times(1)).updateAnalysis(newScores, newDominant);
        verify(mockStats, times(1)).addScore(80);
    }

    // --- 2. 최초 저장 테스트 ---
    @Test
    @DisplayName("최초 분석 결과 저장 시 PostEmotion이 저장되고 통계가 정확히 추가되어야 한다")
    void saveAndApplyAnalysis_shouldSaveAndApplyStats() {
        // Given
        EmotionScores newScores = EmotionScores.builder().loveScore(70).build();
        EmotionType dominantType = EmotionType.LOVE;

        ArgumentCaptor<PostEmotion> postEmotionCaptor = ArgumentCaptor.forClass(PostEmotion.class);

        when(statsRepository.findByCategory_IdAndEmotionType(any(), eq(EmotionType.LOVE)))
                .thenReturn(Optional.of(mockStats));

        // save 호출 시 실제 객체 캡처 및 반환
        when(postEmotionRepository.save(postEmotionCaptor.capture())).thenAnswer(invocation -> invocation.getArgument(0));

        // When
        PostEmotion result = postEmotionService.saveAndApplyAnalysis(mockPost, newScores, dominantType);

        // Then
        verify(postEmotionRepository, times(1)).save(any(PostEmotion.class));

        PostEmotion capturedPostEmotion = postEmotionCaptor.getValue();
        assertTrue(capturedPostEmotion.isAnalyzed(), "저장된 PostEmotion은 분석 완료 상태여야 한다.");

        verify(mockStats, times(1)).addScore(70);
        assertNotNull(result);
    }
}