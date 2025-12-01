    package com.feelscore.back.dto;

    import com.feelscore.back.entity.EmotionScores;
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

        // --- 1. AI 감정 분석 요청 (AI 서버로 전송) ---
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

        // --- 2. AI 감정 분석 응답 (AI 서버에서 수신) ---
        @Getter
        @NoArgsConstructor
        @AllArgsConstructor
        @Builder
        public static class AnalysisResponse {
            // AI 서버의 응답 구조를 따라 9개 필드를 유지합니다.
            private Long postId;
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
                // 🚨 리팩토링 적용: 9개 필드를 EmotionScores 객체로 묶어 엔티티에 전달
                EmotionScores scores = EmotionScores.builder()
                        .joyScore(joyScore)
                        .sadnessScore(sadnessScore)
                        .angerScore(angerScore)
                        .fearScore(fearScore)
                        .disgustScore(disgustScore)
                        .surpriseScore(surpriseScore)
                        .contemptScore(contemptScore)
                        .loveScore(loveScore)
                        .neutralScore(neutralScore)
                        .build();

                return PostEmotion.builder()
                        .post(post)
                        .scores(scores) // ⬅️ EmotionScores 객체 전달
                        .dominantEmotion(dominantEmotion)
                        // isAnalyzed는 서비스 계층에서 postEmotion.markAsAnalyzed()로 처리하는 것이 명확합니다.
                        .build();
            }
        }

        // --- 3. 감정 분석 결과 응답 (클라이언트에게 전송) ---
        @Getter
        @NoArgsConstructor
        @AllArgsConstructor
        @Builder
        public static class Response {
            private Long postId;
            private Map<String, Integer> emotions; // 감정명: 점수
            private EmotionType dominantEmotion; // 우세 감정
            private boolean isAnalyzed; // boolean 타입 사용

            public static Response from(PostEmotion postEmotion) {
                // 🚨 리팩토링 적용: EmotionScores를 통해 점수 획득
                EmotionScores scores = postEmotion.getScores();

                Map<String, Integer> emotions = new HashMap<>();
                emotions.put("joy", scores.getJoyScore());
                emotions.put("sadness", scores.getSadnessScore());
                emotions.put("anger", scores.getAngerScore());
                emotions.put("fear", scores.getFearScore());
                emotions.put("disgust", scores.getDisgustScore());
                emotions.put("surprise", scores.getSurpriseScore());
                emotions.put("contempt", scores.getContemptScore());
                emotions.put("love", scores.getLoveScore());
                emotions.put("neutral", scores.getNeutralScore());

                return Response.builder()
                        .postId(postEmotion.getPost().getId())
                        .emotions(emotions)
                        .dominantEmotion(postEmotion.getDominantEmotion())
                        .isAnalyzed(postEmotion.isAnalyzed()) // boolean의 Getter는 isAnalyzed()
                        .build();
            }
        }

        // --- 4. 감정 점수만 간단히 응답 (게시글 목록에서 사용) ---
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

            // 우세 감정의 점수 추출 (EmotionScores의 getScoreByType 활용)
            private static Integer getDominantScore(PostEmotion pe) {
                if (pe.getDominantEmotion() == null || pe.getScores() == null) return 0;

                // 🚨 리팩토링 적용: EmotionScores의 유용한 메서드 사용
                return pe.getScores().getScoreByType(pe.getDominantEmotion());
            }
        }
    }