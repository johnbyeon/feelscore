package com.feelscore.back.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.Arrays;
import java.util.Comparator;

@Embeddable // JPA에게 이 클래스가 다른 엔티티의 컬럼으로 포함됨을 알립니다.
@Getter // 필드에 대한 getter 메서드를 자동 생성합니다.
@NoArgsConstructor(access = AccessLevel.PROTECTED) // JPA 사용을 위한 기본 생성자를 Protected 레벨로 생성합니다.
public class EmotionScores {

    @Column(nullable = false) // DB 컬럼 설정: NULL을 허용하지 않습니다.
    private Integer joyScore = 0; // 기쁨 점수, 필드 레벨에서 0으로 초기화합니다.

    @Column(nullable = false)
    private Integer sadnessScore = 0; // 슬픔 점수

    @Column(nullable = false)
    private Integer angerScore = 0; // 분노 점수

    @Column(nullable = false)
    private Integer fearScore = 0; // 두려움 점수

    @Column(nullable = false)
    private Integer disgustScore = 0; // 혐오 점수

    @Column(nullable = false)
    private Integer surpriseScore = 0; // 놀라움 점수

    @Column(nullable = false)
    private Integer contemptScore = 0; // 경멸 점수

    @Column(nullable = false)
    private Integer loveScore = 0; // 사랑 점수

    @Column(nullable = false)
    private Integer neutralScore = 0; // 중립 점수

    @Builder // 빌더 패턴을 사용하여 객체를 생성할 수 있게 합니다.
    public EmotionScores(Integer joyScore, Integer sadnessScore, Integer angerScore,
                         Integer fearScore, Integer disgustScore, Integer surpriseScore,
                         Integer contemptScore, Integer loveScore, Integer neutralScore) {
        // 입력된 값이 null이면 0으로 설정하여 데이터 무결성을 보장합니다.
        this.joyScore = joyScore != null ? joyScore : 0;
        this.sadnessScore = sadnessScore != null ? sadnessScore : 0;
        this.angerScore = angerScore != null ? angerScore : 0;
        this.fearScore = fearScore != null ? fearScore : 0;
        this.disgustScore = disgustScore != null ? disgustScore : 0;
        this.surpriseScore = surpriseScore != null ? surpriseScore : 0;
        this.contemptScore = contemptScore != null ? contemptScore : 0;
        this.loveScore = loveScore != null ? loveScore : 0;
        this.neutralScore = neutralScore != null ? neutralScore : 0;
    }

    // 특정 감정 타입의 점수 조회 (Enum 기반 동적 조회)
    public Integer getScoreByType(EmotionType type) {
        return switch (type) { // Java 14+의 스위치 표현식을 사용합니다.
            case JOY -> joyScore; // 입력된 EmotionType에 해당하는 점수 필드를 반환합니다.
            case SADNESS -> sadnessScore;
            case ANGER -> angerScore;
            case FEAR -> fearScore;
            case DISGUST -> disgustScore;
            case SURPRISE -> surpriseScore;
            case CONTEMPT -> contemptScore;
            case LOVE -> loveScore;
            case NEUTRAL -> neutralScore;
        };
    }

    // 가장 높은 점수의 감정 타입 찾기 (우세 감정 판단)
    public EmotionType getDominantEmotionType() {
        return Arrays.stream(EmotionType.values()) // 모든 EmotionType Enum 값을 스트림으로 가져옵니다.
                .max(Comparator.comparingInt(this::getScoreByType)) // getScoreByType을 기준으로 가장 높은 점수를 가진 Enum을 찾습니다.
                .orElse(EmotionType.NEUTRAL); // 만약 점수가 모두 0이거나 찾을 수 없으면 NEUTRAL을 반환합니다.
    }

    // 모든 점수가 0인지 확인 (게시글이 무의미한 감정 분석 결과인지 체크)
    public boolean isEmpty() {
        return Arrays.stream(EmotionType.values()) // 모든 EmotionType을 순회합니다.
                .allMatch(type -> getScoreByType(type) == 0); // 모든 감정 타입의 점수가 0인지 확인합니다.
    }

    // 모든 감정 점수의 총합을 계산합니다. (통계 업데이트 시 유용)
    public Integer getTotalScore() {
        return Arrays.stream(EmotionType.values()) // 모든 EmotionType을 순회합니다.
                .mapToInt(this::getScoreByType) // 각 타입에 해당하는 점수(Integer)를 int 스트림으로 변환합니다.
                .sum(); // int 스트림의 모든 값을 더하여 총점을 반환합니다.
    }

    // 점수가 모두 0 이상인지 확인합니다. (데이터 유효성 검증)
    public boolean isValid() {
        return Arrays.stream(EmotionType.values()) // 모든 EmotionType을 순회합니다.
                .allMatch(type -> getScoreByType(type) >= 0); // 각 점수가 0보다 작지 않은지 확인합니다.
    }
}