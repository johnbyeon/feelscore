package com.feelscore.back.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
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
    private EmotionType emotionType; // JOY, ANGER...

    // 글의 개수도 계속 늘어나니까 Long (BIGINT) 추천
    private Long count;

    // ⭐️ 수정됨: 점수 총합을 BIGINT로 처리하기 위해 Long 사용
    // DB에서는 bigint 타입으로 생성됨
    @Column(columnDefinition = "BIGINT DEFAULT 0")
    private Long totalScore;

    // 점수 누적 메서드 (파라미터는 int로 들어오지만 내부는 Long으로 더함)
    public void addScore(Integer score) {
        if (this.count == null) this.count = 0L;
        if (this.totalScore == null) this.totalScore = 0L;

        this.count += 1;
        this.totalScore += score; // Long + Integer -> Long (안전함)
    }
}
