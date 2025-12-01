package com.feelscore.back.service;

import com.feelscore.back.dto.CategoryEmotionStatsDto;
import com.feelscore.back.dto.CategoryEmotionStatsDto.GlobalStatProjection;
import com.feelscore.back.entity.EmotionType;
import com.feelscore.back.repository.CategoryEmotionStatsRepository;
import com.feelscore.back.repository.CategoryRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CategoryEmotionStatsServiceTest {

    @InjectMocks
    private CategoryEmotionStatsService statsService;

    @Mock
    private CategoryEmotionStatsRepository statsRepository;

    @Mock
    private CategoryRepository categoryRepository;

    @Test
    @DisplayName("전체 감정 순위(Count 기준) 조회 시 랭킹이 정확히 매겨져야 한다")
    void getGlobalEmotionRankingByCount_shouldReturnRankedList() {
        // Given
        // 1. 가짜 Projection 객체 생성 (Mockito로 인터페이스 Mocking)
        GlobalStatProjection rank1 = mock(GlobalStatProjection.class);
        when(rank1.getEmotionType()).thenReturn(EmotionType.JOY);
        when(rank1.getTotalCount()).thenReturn(100L);
        when(rank1.getTotalScore()).thenReturn(5000L);

        GlobalStatProjection rank2 = mock(GlobalStatProjection.class);
        when(rank2.getEmotionType()).thenReturn(EmotionType.SADNESS);
        when(rank2.getTotalCount()).thenReturn(50L);
        when(rank2.getTotalScore()).thenReturn(2000L);

        // 2. 리포지토리 반환값 설정
        when(statsRepository.getEmotionRankingByCountProjection())
                .thenReturn(List.of(rank1, rank2));

        // When
        List<CategoryEmotionStatsDto.GlobalRankingResponse> result =
                statsService.getGlobalEmotionRankingByCount();

        // Then
        assertEquals(2, result.size());

        // 1위 확인
        assertEquals(EmotionType.JOY, result.get(0).getEmotionType());
        assertEquals(1, result.get(0).getRank()); // 랭킹 1위 확인

        // 2위 확인
        assertEquals(EmotionType.SADNESS, result.get(1).getEmotionType());
        assertEquals(2, result.get(1).getRank()); // 랭킹 2위 확인
    }
}