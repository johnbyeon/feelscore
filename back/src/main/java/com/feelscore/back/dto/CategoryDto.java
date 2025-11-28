package com.feelscore.back.dto;

import com.feelscore.back.entity.Category;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.List;
import java.util.stream.Collectors;

public class CategoryDto {

    // 카테고리 생성 요청
    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class CreateRequest {
        private String name;
        private Integer depth; // 1: 대분류, 2: 소분류
        private Long parentId; // 소분류인 경우 부모 ID

        public Category toEntity(Category parent) {
            return Category.builder()
                    .name(name)
                    .depth(depth)
                    .parent(parent)
                    .build();
        }
    }

    // 카테고리 응답 (기본)
    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class Response {
        private Long id;
        private String name;
        private Integer depth;
        private Long parentId;

        public static Response from(Category category) {
            return Response.builder()
                    .id(category.getId())
                    .name(category.getName())
                    .depth(category.getDepth())
                    .parentId(category.getParent() != null ? category.getParent().getId() : null)
                    .build();
        }
    }

    // 자식 카테고리 포함 응답 (계층 구조)
    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class ResponseWithChildren {
        private Long id;
        private String name;
        private Integer depth;
        private List<Response> children; // 소분류 리스트

        public static ResponseWithChildren from(Category category) {
            return ResponseWithChildren.builder()
                    .id(category.getId())
                    .name(category.getName())
                    .depth(category.getDepth())
                    .children(category.getChildren().stream()
                            .map(Response::from)
                            .collect(Collectors.toList()))
                    .build();
        }
    }

    // 간단한 카테고리 정보 (게시글 표시용)
    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class SimpleResponse {
        private Long id;
        private String name;

        public static SimpleResponse from(Category category) {
            return SimpleResponse.builder()
                    .id(category.getId())
                    .name(category.getName())
                    .build();
        }
    }
}