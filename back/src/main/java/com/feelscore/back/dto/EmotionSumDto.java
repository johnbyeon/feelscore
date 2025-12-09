package com.feelscore.back.dto;

import com.feelscore.back.entity.EmotionType;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.HashMap;
import java.util.Map;

@Getter
@NoArgsConstructor
public class EmotionSumDto {
    private Long categoryId;
    private Long joy;
    private Long sadness;
    private Long anger;
    private Long fear;
    private Long disgust;
    private Long surprise;
    private Long contempt;
    private Long love;
    private Long anticipation;
    private Long trust;
    private Long neutral;

    public EmotionSumDto(Long categoryId, Long joy, Long sadness, Long anger, Long fear, Long disgust,
            Long surprise, Long contempt, Long love, Long anticipation, Long trust, Long neutral) {
        this.categoryId = categoryId;
        this.joy = joy != null ? joy : 0L;
        this.sadness = sadness != null ? sadness : 0L;
        this.anger = anger != null ? anger : 0L;
        this.fear = fear != null ? fear : 0L;
        this.disgust = disgust != null ? disgust : 0L;
        this.surprise = surprise != null ? surprise : 0L;
        this.contempt = contempt != null ? contempt : 0L;
        this.love = love != null ? love : 0L;
        this.anticipation = anticipation != null ? anticipation : 0L;
        this.trust = trust != null ? trust : 0L;
        this.neutral = neutral != null ? neutral : 0L;
    }

    public Map<EmotionType, Long> toMap() {
        Map<EmotionType, Long> map = new HashMap<>();
        map.put(EmotionType.JOY, joy);
        map.put(EmotionType.SADNESS, sadness);
        map.put(EmotionType.ANGER, anger);
        map.put(EmotionType.FEAR, fear);
        map.put(EmotionType.DISGUST, disgust);
        map.put(EmotionType.SURPRISE, surprise);
        map.put(EmotionType.CONTEMPT, contempt);
        map.put(EmotionType.LOVE, love);
        map.put(EmotionType.ANTICIPATION, anticipation);
        map.put(EmotionType.TRUST, trust);
        map.put(EmotionType.NEUTRAL, neutral);
        return map;
    }
}
