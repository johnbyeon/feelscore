package com.feelscore.back.dto;

import com.feelscore.back.entity.Users;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

// PostDto에서 참조하는 UsersDto의 구조를 정의합니다.
public class UsersDto {

    /**
     * 게시글 상세/목록 조회 시 필요한 사용자 정보 (닉네임, ID 등)
     */
    @Getter
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor
    @Builder
    public static class SimpleResponse {
        private Long id;
        private String nickname; // PostDto.ListResponse에서 post.getUsers().getNickname()을 사용하므로 닉네임 필드 필수

        public static SimpleResponse from(Users users) {
            // Null 체크는 서비스에서 보장되어야 하나, 안전을 위해 Users 엔티티가 존재한다고 가정
            return SimpleResponse.builder()
                    .id(users.getId())
                    .nickname(users.getNickname())
                    .build();
        }
    }

    // (다른 DTO들은 필요에 따라 추가됩니다.)
}
