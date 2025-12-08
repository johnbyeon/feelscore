package com.feelscore.back.dto;

import com.feelscore.back.entity.Users;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class BlockDto {
    private Long userId;
    private String nickname;
    private String email;

    public static BlockDto from(Users user) {
        return BlockDto.builder()
                .userId(user.getId())
                .nickname(user.getNickname())
                .email(user.getEmail())
                .build();
    }
}
