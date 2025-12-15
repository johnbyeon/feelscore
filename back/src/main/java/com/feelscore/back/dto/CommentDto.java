package com.feelscore.back.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.feelscore.back.entity.Comment;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

public class CommentDto {

    @Getter
    @NoArgsConstructor
    public static class Request {
        private String content;
        private Long parentId;
    }

    @Getter
    @Builder
    @AllArgsConstructor
    public static class Response {
        private Long id;
        private String content;
        private Long userId;
        private String userNickname;
        private String userProfileImageUrl;
        @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd HH:mm:ss")
        private LocalDateTime createdAt;
        private Long parentId;
        private java.util.List<Response> children;

        private java.util.Map<com.feelscore.back.entity.EmotionType, Long> reactionCounts;
        private com.feelscore.back.entity.EmotionType myReaction;

        public static Response from(Comment comment,
                java.util.Map<com.feelscore.back.entity.EmotionType, Long> reactionCounts,
                com.feelscore.back.entity.EmotionType myReaction) {
            return Response.builder()
                    .id(comment.getId())
                    .content(comment.getContent())
                    .userId(comment.getUsers().getId())
                    .userNickname(comment.getUsers().getNickname())
                    .userProfileImageUrl(comment.getUsers().getProfileImageUrl())
                    .createdAt(comment.getCreatedAt())
                    .parentId(comment.getParent() != null ? comment.getParent().getId() : null)
                    .children(new java.util.ArrayList<>())
                    .reactionCounts(reactionCounts)
                    .myReaction(myReaction)
                    .build();
        }

        public static Response from(Comment comment) {
            return Response.builder()
                    .id(comment.getId())
                    .content(comment.getContent())
                    .userId(comment.getUsers().getId())
                    .userNickname(comment.getUsers().getNickname())
                    .userProfileImageUrl(comment.getUsers().getProfileImageUrl())
                    .createdAt(comment.getCreatedAt())
                    .parentId(comment.getParent() != null ? comment.getParent().getId() : null)
                    .children(new java.util.ArrayList<>())
                    .build();
        }
    }
}
