package com.feelscore.back.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "category_emotion_stats")
public class CategoryEmotionStats {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "stat_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id")
    private Category category;

    @Enumerated(EnumType.STRING)
    private EmotionType emotionType; // JOY, ANGER 등

    private Long count; // 글 개수

    @Column(columnDefinition = "BIGINT DEFAULT 0")
    private Long totalScore; // 점수 총합

    @Builder
    public CategoryEmotionStats(Category category, EmotionType emotionType) {
        this.category = category;
        this.emotionType = emotionType;
        this.count = 0L;
        this.totalScore = 0L;
    }

    // 점수 누적 메서드
    public void addScore(Integer score) {
        if (this.count == null) this.count = 0L;
        if (this.totalScore == null) this.totalScore = 0L;

        this.count += 1;
        this.totalScore += score;
    }
}