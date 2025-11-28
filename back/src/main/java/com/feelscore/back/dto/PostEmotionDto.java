package com.feelscore.back.dto;

import com.feelscore.back.entity.EmotionType;
import com.feelscore.back.entity.Post;
import com.feelscore.back.entity.PostEmotion;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.HashMap;
import java.util.Map;

public class PostEmotionDto {

    // AI 감정 분석 요청 (AI 서버로 전송)
    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class AnalysisRequest {
        private Long postId;
        private String content;

        public static AnalysisRequest from(Post post) {
            return AnalysisRequest.builder()
                    .postId(post.getId())
                    .content(post.getContent())
                    .build();
        }
    }

    // AI 감정 분석 응답 (AI 서버에서 수신)
    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class AnalysisResponse {
        private Integer joyScore;
        private Integer sadnessScore;
        private Integer angerScore;
        private Integer fearScore;
        private Integer disgustScore;
        private Integer surpriseScore;
        private Integer contemptScore;
        private Integer loveScore;
        private Integer neutralScore;
        private EmotionType dominantEmotion;

        public PostEmotion toEntity(Post post) {
            return PostEmotion.builder()
                    .post(post)
                    .joyScore(joyScore)
                    .sadnessScore(sadnessScore)
                    .angerScore(angerScore)
                    .fearScore(fearScore)
                    .disgustScore(disgustScore)
                    .surpriseScore(surpriseScore)
                    .contemptScore(contemptScore)
                    .loveScore(loveScore)
                    .neutralScore(neutralScore)
                    .dominantEmotion(dominantEmotion)
                    .isAnalyzed(true)
                    .build();
        }
    }

    // 감정 분석 결과 응답 (클라이언트에게 전송)
    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class Response {
        private Long postId;
        private Map<String, Integer> emotions; // 감정명: 점수
        private EmotionType dominantEmotion; // 우세 감정
        private Boolean isAnalyzed;

        public static Response from(PostEmotion postEmotion) {
            Map<String, Integer> emotions = new HashMap<>();
            emotions.put("joy", postEmotion.getJoyScore());
            emotions.put("sadness", postEmotion.getSadnessScore());
            emotions.put("anger", postEmotion.getAngerScore());
            emotions.put("fear", postEmotion.getFearScore());
            emotions.put("disgust", postEmotion.getDisgustScore());
            emotions.put("surprise", postEmotion.getSurpriseScore());
            emotions.put("contempt", postEmotion.getContemptScore());
            emotions.put("love", postEmotion.getLoveScore());
            emotions.put("neutral", postEmotion.getNeutralScore());

            return Response.builder()
                    .postId(postEmotion.getPost().getId())
                    .emotions(emotions)
                    .dominantEmotion(postEmotion.getDominantEmotion())
                    .isAnalyzed(postEmotion.getIsAnalyzed())
                    .build();
        }
    }

    // 감정 점수만 간단히 응답 (게시글 목록에서 사용)
    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class SimpleResponse {
        private EmotionType dominantEmotion;
        private Integer dominantScore;

        public static SimpleResponse from(PostEmotion postEmotion) {
            Integer dominantScore = getDominantScore(postEmotion);

            return SimpleResponse.builder()
                    .dominantEmotion(postEmotion.getDominantEmotion())
                    .dominantScore(dominantScore)
                    .build();
        }

        // 우세 감정의 점수 추출
        private static Integer getDominantScore(PostEmotion pe) {
            if (pe.getDominantEmotion() == null) return 0;

            return switch (pe.getDominantEmotion()) {
                case JOY -> pe.getJoyScore();
                case SADNESS -> pe.getSadnessScore();
                case ANGER -> pe.getAngerScore();
                case FEAR -> pe.getFearScore();
                case DISGUST -> pe.getDisgustScore();
                case SURPRISE -> pe.getSurpriseScore();
                case CONTEMPT -> pe.getContemptScore();
                case LOVE -> pe.getLoveScore();
                case NEUTRAL -> pe.getNeutralScore();
            };
        }
    }
}