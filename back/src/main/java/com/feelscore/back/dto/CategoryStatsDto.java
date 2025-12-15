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
    private Long commentCount;
    private String trend; // UP, DOWN, STABLE, NONE
    private List<CategoryStatsDto> children;
}
