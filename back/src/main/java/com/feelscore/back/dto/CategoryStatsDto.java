package com.feelscore.back.dto;

import com.feelscore.back.entity.EmotionType;
import lombok.Builder;
import lombok.Getter;

import java.util.List;

@Getter
@Builder
public class CategoryStatsDto {
    private Long categoryId;
    private String name;
    private EmotionType dominantEmotion;
    private Long score;
    private List<CategoryStatsDto> children;
}
