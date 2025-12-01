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
    @JoinColumn(name = "post_id", nullable = false)
    private Post post;

    @Embedded // 9가지 감정 점수를 하나의 객체로 관리
    private EmotionScores scores;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private EmotionType dominantEmotion = EmotionType.NEUTRAL; // 기본값 설정

    @Column(nullable = false)
    private boolean isAnalyzed = false; // primitive 타입 사용

    @Builder
    public PostEmotion(Post post, EmotionScores scores, EmotionType dominantEmotion) {
        if (post == null) {
            throw new IllegalArgumentException("게시글은 필수입니다.");
        }
        this.post = post;
        this.scores = scores;
        this.dominantEmotion = dominantEmotion != null ? dominantEmotion : EmotionType.NEUTRAL;
        this.isAnalyzed = false;
    }

    // 감정 분석 결과 업데이트 (재분석 시 사용)
    public void updateAnalysis(EmotionScores newScores, EmotionType dominantEmotion) {
        if (newScores == null) {
            throw new IllegalArgumentException("감정 점수는 필수입니다.");
        }
        this.scores = newScores;
        this.dominantEmotion = dominantEmotion != null ? dominantEmotion : EmotionType.NEUTRAL;
        this.isAnalyzed = true;
    }

    // 분석 완료 처리 (점수 없이 완료만 표시할 때 사용)
    public void markAsAnalyzed() {
        this.isAnalyzed = true;
    }
}