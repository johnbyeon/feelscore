package com.feelscore.back.dto;

import com.feelscore.back.entity.EmotionType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.Map;

public class ReactionDto {

    @Getter
    @NoArgsConstructor
    public static class Request {
        private EmotionType emotionType;
    }

    @Getter
    @Builder
    @AllArgsConstructor
    public static class Stats {
        private Map<EmotionType, Long> reactionCounts;
        private EmotionType myReaction;
    }
}
