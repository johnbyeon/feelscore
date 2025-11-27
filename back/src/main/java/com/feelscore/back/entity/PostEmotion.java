package com.feelscore.back.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
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

    // 9가지 감정 점수
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
    private EmotionType dominantEmotion; // 가장 높은 점수의 감정

    private Boolean isAnalyzed; // 분석 완료 여부

    @Builder
    public PostEmotion(Post post, Integer joyScore, Integer sadnessScore,
                       Integer angerScore, Integer fearScore, Integer disgustScore,
                       Integer surpriseScore, Integer contemptScore, Integer loveScore,
                       Integer neutralScore, EmotionType dominantEmotion, Boolean isAnalyzed) {
        this.post = post;
        this.joyScore = joyScore != null ? joyScore : 0;
        this.sadnessScore = sadnessScore != null ? sadnessScore : 0;
        this.angerScore = angerScore != null ? angerScore : 0;
        this.fearScore = fearScore != null ? fearScore : 0;
        this.disgustScore = disgustScore != null ? disgustScore : 0;
        this.surpriseScore = surpriseScore != null ? surpriseScore : 0;
        this.contemptScore = contemptScore != null ? contemptScore : 0;
        this.loveScore = loveScore != null ? loveScore : 0;
        this.neutralScore = neutralScore != null ? neutralScore : 0;
        this.dominantEmotion = dominantEmotion;
        this.isAnalyzed = isAnalyzed != null ? isAnalyzed : false;
    }
}