package com.feelscore.back.dto;

import com.feelscore.back.entity.Category;
import com.feelscore.back.entity.Post;
import com.feelscore.back.entity.PostStatus;
import com.feelscore.back.entity.Users;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.LocalDateTime;

public class PostDto {

    // 게시글 작성 요청
    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class CreateRequest {
        @NotBlank(message = "내용을 입력해주세요")
        private String content;

        @NotNull(message = "카테고리를 선택해주세요")
        private Long categoryId;

        private String imageUrl; // 이미지 키 추가

        public Post toEntity(Users users, Category category) {
            return Post.builder()
                    .content(content)
                    .users(users)
                    .category(category)
                    .imageUrl(imageUrl)
                    .build();
        }
    }

    // 게시글 수정 요청
    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    public static class UpdateRequest {
        @NotBlank(message = "내용을 입력해주세요")
        private String content;

        @NotNull(message = "카테고리를 선택해주세요")
        private Long categoryId;

        private String imageUrl; // 이미지 URL 추가
    }

    // 게시글 상세 응답
    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class Response {
        private Long id;
        private String content;
        private PostStatus status;
        private String blindReason;
        private UsersDto.SimpleResponse user;
        private CategoryDto.SimpleResponse category;
        private String imageUrl;
        private LocalDateTime createdAt;
        private LocalDateTime updatedAt;

        private Long commentCount;
        private java.util.Map<com.feelscore.back.entity.EmotionType, Long> reactionCounts;

        public static Response from(Post post, Long commentCount,
                java.util.Map<com.feelscore.back.entity.EmotionType, Long> reactionCounts) {
            return Response.builder()
                    .id(post.getId())
                    .content(post.getContent())
                    .status(post.getStatus())
                    .blindReason(post.getBlindReason())
                    .user(UsersDto.SimpleResponse.from(post.getUsers()))
                    .category(CategoryDto.SimpleResponse.from(post.getCategory()))
                    .imageUrl(post.getImageUrl())
                    .createdAt(post.getCreatedAt())
                    .updatedAt(post.getUpdatedAt())
                    .commentCount(commentCount)
                    .reactionCounts(reactionCounts)
                    .build();
        }

        public static Response from(Post post) {
            return Response.builder()
                    .id(post.getId())
                    .content(post.getContent())
                    .status(post.getStatus())
                    .blindReason(post.getBlindReason())
                    .user(UsersDto.SimpleResponse.from(post.getUsers()))
                    .category(CategoryDto.SimpleResponse.from(post.getCategory()))
                    .imageUrl(post.getImageUrl())
                    .createdAt(post.getCreatedAt())
                    .updatedAt(post.getUpdatedAt())
                    .commentCount(0L)
                    .reactionCounts(new java.util.HashMap<>())
                    .build();
        }
    }

    // 게시글 목록 응답 (간소화)
    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class ListResponse {
        private Long id;
        private String content;
        private PostStatus status;
        private Long userId; // 작성자 ID 추가
        private String userNickname;
        private String userProfileImageUrl; // 작성자 프로필 이미지 추가
        private Long categoryId; // 카테고리 ID 추가
        private String categoryName;
        private String imageUrl;
        private LocalDateTime createdAt;
        private String dominantEmotion; // 감정 분석 결과 추가

        private Long commentCount;
        private java.util.Map<com.feelscore.back.entity.EmotionType, Long> reactionCounts;

        public static ListResponse from(Post post, String dominantEmotion, Long commentCount,
                java.util.Map<com.feelscore.back.entity.EmotionType, Long> reactionCounts) {
            return ListResponse.builder()
                    .id(post.getId())
                    .content(post.getContent())
                    .status(post.getStatus())
                    .userId(post.getUsers().getId())
                    .userNickname(post.getUsers().getNickname())
                    .userProfileImageUrl(post.getUsers().getProfileImageUrl())
                    .categoryId(post.getCategory().getId())
                    .categoryName(post.getCategory().getName())
                    .imageUrl(post.getImageUrl())
                    .createdAt(post.getCreatedAt())
                    .dominantEmotion(dominantEmotion)
                    .commentCount(commentCount)
                    .reactionCounts(reactionCounts)
                    .build();
        }

        public static ListResponse from(Post post) {
            return ListResponse.builder()
                    .id(post.getId())
                    .content(post.getContent())
                    .status(post.getStatus())
                    .userId(post.getUsers().getId())
                    .userNickname(post.getUsers().getNickname())
                    .userProfileImageUrl(post.getUsers().getProfileImageUrl())
                    .categoryId(post.getCategory().getId())
                    .categoryName(post.getCategory().getName())
                    .imageUrl(post.getImageUrl())
                    .createdAt(post.getCreatedAt())
                    .build();
        }
    }

    // 블라인드 처리 요청
    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    public static class BlindRequest {
        @NotBlank(message = "블라인드 사유를 입력해주세요")
        private String blindReason;
    }
}