package com.feelscore.back.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "post_emotions")
public class PostEmotion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "analysis_id")
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "post_id")
    private Post post;

    // ⭐️ 9가지 감정 점수 (Integer)
    // AI가 분석 못했을 때 null 방지하려면 기본값 0을 넣거나 @Column(nullable=false) 추천
    private Integer joyScore;
    private Integer sadnessScore;
    private Integer angerScore;
    private Integer fearScore;
    private Integer disgustScore;
    private Integer surpriseScore;
    private Integer contemptScore;
    private Integer loveScore;
    private Integer neutralScore;

    @Enumerated(EnumType.STRING)
    private EmotionType dominantEmotion; // 이 중에서 점수가 가장 높은 놈 (색인용)

    private Boolean isAnalyzed; // 분석 완료 여부

    // 편의상 생성자나 빌더 패턴을 쓸 때 Python에서 온 JSON을 바로 매핑하기 좋게 필드명 통일함
}
