package com.feelscore.back.service;

import com.feelscore.back.dto.EmotionSumDto;
import com.feelscore.back.dto.UserEmotionStatsDto;
import com.feelscore.back.entity.EmotionType;
import com.feelscore.back.entity.PostStatus;
import com.feelscore.back.repository.PostEmotionRepository;
import com.feelscore.back.repository.PostRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class UserStatsService {

    private final PostEmotionRepository postEmotionRepository;
    private final PostRepository postRepository;

    @Transactional(readOnly = true)
    public UserEmotionStatsDto getUserEmotionStats(Long userId) {
        // 1. 유저의 총 게시글 수 조회 (Context) - 정상 게시글만 카운트
        Long totalPosts = postRepository.countByUsers_IdAndStatus(userId, PostStatus.NORMAL);

        // 2. 감정 점수 합계 조회
        EmotionSumDto sumDto = postEmotionRepository.sumScoresByUserId(userId)
                .orElse(new EmotionSumDto(userId, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L));

        Map<EmotionType, Long> emotionCounts = sumDto.toMap();

        // 3. Dominant Emotion 계산
        EmotionType dominantEmotion = EmotionType.NEUTRAL;
        long maxScore = 0;

        for (Map.Entry<EmotionType, Long> entry : emotionCounts.entrySet()) {
            if (entry.getKey() != EmotionType.NEUTRAL && entry.getValue() > maxScore) {
                maxScore = entry.getValue();
                dominantEmotion = entry.getKey();
            }
        }

        // 4. DTO 생성
        return UserEmotionStatsDto.builder()
                .userId(userId)
                .totalPosts(totalPosts)
                .emotionCounts(emotionCounts)
                .dominantEmotion(dominantEmotion)
                .build();
    }
}
