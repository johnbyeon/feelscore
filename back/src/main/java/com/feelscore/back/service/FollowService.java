package com.feelscore.back.service;

import com.feelscore.back.dto.FollowDto;
import com.feelscore.back.dto.UsersDto;
import com.feelscore.back.entity.Follow;
import com.feelscore.back.entity.Users;
import com.feelscore.back.repository.FollowRepository;
import com.feelscore.back.repository.BlockRepository;
import com.feelscore.back.repository.UserRepository;
import lombok.Builder;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.NoSuchElementException;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class FollowService {

        private final FollowRepository followRepository;
        private final UserRepository userRepository;
        private final BlockRepository blockRepository;

        /**
         * 팔로우 토글 (팔로우 <-> 언팔로우)
         */
        @Transactional
        public boolean toggleFollow(Long currentUserId, Long targetUserId) {
                if (currentUserId.equals(targetUserId)) {
                        throw new IllegalArgumentException("자기 자신을 팔로우할 수 없습니다.");
                }

                Users currentUser = userRepository.findById(currentUserId)
                                .orElseThrow(() -> new NoSuchElementException(
                                                "User not found with id: " + currentUserId));
                Users targetUser = userRepository.findById(targetUserId)
                                .orElseThrow(() -> new NoSuchElementException(
                                                "Target user not found with id: " + targetUserId));

                // 차단 관계 확인 (서로 차단되어 있으면 팔로우 불가)
                if (blockRepository.existsByBlockerAndBlocked(currentUser, targetUser) ||
                                blockRepository.existsByBlockerAndBlocked(targetUser, currentUser)) {
                        throw new IllegalStateException("차단된 유저입니다.");
                }

                if (followRepository.existsByFollowerAndFollowing(currentUser, targetUser)) {
                        followRepository.deleteByFollowerAndFollowing(currentUser, targetUser);
                        return false; // 언팔로우 됨
                } else {
                        Follow follow = Follow.builder()
                                        .follower(currentUser)
                                        .following(targetUser)
                                        .build();
                        followRepository.save(follow);
                        return true; // 팔로우 됨
                }
        }

        /**
         * 팔로우 통계 조회 (팔로워 수, 팔로잉 수, 맞팔 여부 등)
         */
        public FollowDto.Stats getStats(Long targetUserId, Long currentUserId) {
                Users targetUser = userRepository.findById(targetUserId)
                                .orElseThrow(() -> new NoSuchElementException(
                                                "User not found with id: " + targetUserId));

                long followerCount = followRepository.countByFollowing(targetUser);
                long followingCount = followRepository.countByFollower(targetUser);
                boolean isFollowing = false;

                if (currentUserId != null) {
                        Users currentUser = userRepository.findById(currentUserId).orElse(null);
                        if (currentUser != null) {
                                isFollowing = followRepository.existsByFollowerAndFollowing(currentUser, targetUser);
                        }
                }

                return FollowDto.Stats.builder()
                                .followerCount(followerCount)
                                .followingCount(followingCount)
                                .isFollowing(isFollowing)
                                .build();
        }

        /**
         * 팔로워 목록 조회
         */
        public List<UsersDto.SimpleResponse> getFollowers(Long userId) {
                Users user = userRepository.findById(userId)
                                .orElseThrow(() -> new NoSuchElementException("User not found with id: " + userId));

                return followRepository.findByFollowing(user).stream()
                                .map(follow -> UsersDto.SimpleResponse.from(follow.getFollower()))
                                .collect(Collectors.toList());
        }

        /**
         * 팔로잉 목록 조회
         */
        public List<UsersDto.SimpleResponse> getFollowings(Long userId) {
                Users user = userRepository.findById(userId)
                                .orElseThrow(() -> new NoSuchElementException("User not found with id: " + userId));

                return followRepository.findByFollower(user).stream()
                                .map(follow -> UsersDto.SimpleResponse.from(follow.getFollowing()))
                                .collect(Collectors.toList());
        }

        @Getter
        @Builder
        public static class FollowDtoInner { // Inner class unused if utilizing separate DTOs, but kept if needed
                private Long userId;
                private String nickname;
                private String email;
        }
}
