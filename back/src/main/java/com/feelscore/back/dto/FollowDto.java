package com.feelscore.back.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import com.fasterxml.jackson.annotation.JsonProperty;

public class FollowDto {

    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class Stats {
        private long followerCount;
        private long followingCount;
        @JsonProperty("isFollowing")
        private boolean isFollowing;
    }
}
