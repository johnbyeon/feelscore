package com.feelscore.back.dto;

import com.feelscore.back.entity.Users;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

public class UsersDto {

    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class SimpleResponse {
        private Long id;
        private String nickname;
        private String email;
        private String role;         // "USER", "ADMIN"
        private String lastLoginAt;  // String (null 허용)

        public static SimpleResponse from(Users user) {
            if (user == null) return null;

            return SimpleResponse.builder()
                    .id(user.getId())
                    .nickname(user.getNickname())
                    .email(user.getEmail())
                    .role(user.getRole() != null ? user.getRole().name() : null)
                    .lastLoginAt(
                            user.getLastLoginAt() != null
                                    ? user.getLastLoginAt().toString()
                                    : null
                    )
                    .build();
        }
    }
}
