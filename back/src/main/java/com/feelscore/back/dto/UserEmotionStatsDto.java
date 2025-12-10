package com.feelscore.back.dto;

import com.feelscore.back.entity.EmotionType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.Map;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserEmotionStatsDto {
    private Long userId;
    private Long totalPosts; // 내가 쓴 글 수
    private Map<EmotionType, Long> emotionCounts; // 감정별 총 점수 (예: JOY -> 150, SADNESS -> 30)
    private EmotionType dominantEmotion; // 가장 많이 느낀 감정
}
