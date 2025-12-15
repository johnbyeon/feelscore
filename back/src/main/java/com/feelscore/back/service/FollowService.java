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
        private final NotificationProducer notificationProducer; // 🔹 알림 발송자 주입
        private final ActiveUserService activeUserService; // 🔹 활성 유저 서비스 주입

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

                        // 🔹 알림 발송
                        if (targetUser.getFcmToken() != null) {
                                com.feelscore.back.dto.NotificationEventDto eventDto = com.feelscore.back.dto.NotificationEventDto
                                                .builder()
                                                .recipientId(targetUser.getId())
                                                .senderId(currentUser.getId())
                                                .type(com.feelscore.back.entity.NotificationType.FOLLOW)
                                                .relatedId(currentUser.getId()) // 팔로우는 관련 ID가 팔로워(나)
                                                .title("새로운 팔로워!")
                                                .body(currentUser.getNickname() + "님이 회원님을 팔로우하기 시작했습니다.")
                                                .build();

                                notificationProducer.sendNotification(eventDto);
                        }

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
        /**
         * 팔로워 목록 조회 (Optional Query)
         */
        public List<UsersDto.SimpleResponse> getFollowers(Long userId, String query) {
                Users user = userRepository.findById(userId)
                                .orElseThrow(() -> new NoSuchElementException("User not found with id: " + userId));

                List<Follow> follows;
                if (query != null && !query.trim().isEmpty()) {
                        follows = followRepository.findByFollowingAndFollower_NicknameContainingIgnoreCase(user, query);
                } else {
                        follows = followRepository.findByFollowing(user);
                }

                return follows.stream()
                                .map(follow -> {
                                        Users follower = follow.getFollower();
                                        boolean isOnline = activeUserService.isUserActive(follower.getId());
                                        // Debug Log
                                        System.out.println("DEBUG: getFollowers - User " + follower.getNickname() +
                                                        " (" + follower.getId() + ") isOnline=" + isOnline);
                                        return UsersDto.SimpleResponse.from(follower, isOnline);
                                })
                                .collect(Collectors.toList());
        }

        /**
         * 팔로잉 목록 조회 (Optional Query: If query exists, Global Search)
         */
        public List<UsersDto.SimpleResponse> getFollowings(Long userId, String query) {
                // If query is present, perform Global Search (All Users)
                if (query != null && !query.trim().isEmpty()) {
                        return userRepository.findByNicknameContainingIgnoreCase(query).stream()
                                        .map(user -> {
                                                boolean isOnline = activeUserService.isUserActive(user.getId());
                                                return UsersDto.SimpleResponse.from(user, isOnline);
                                        })
                                        .collect(Collectors.toList());
                }

                // If query is empty, return My Followings
                Users user = userRepository.findById(userId)
                                .orElseThrow(() -> new NoSuchElementException("User not found with id: " + userId));

                return followRepository.findByFollower(user).stream()
                                .map(follow -> {
                                        Users following = follow.getFollowing();
                                        boolean isOnline = activeUserService.isUserActive(following.getId());
                                        return UsersDto.SimpleResponse.from(following, isOnline);
                                })
                                .collect(Collectors.toList());
        }

        /**
         * 팔로잉 유저 엔티티 목록 조회 (내부 로직용)
         */
        public List<Users> getFollowingUsers(Long userId) {
                Users user = userRepository.findById(userId)
                                .orElseThrow(() -> new NoSuchElementException("User not found with id: " + userId));

                return followRepository.findByFollower(user).stream()
                                .map(Follow::getFollowing)
                                .collect(Collectors.toList());
        }

        @Getter
        @Builder
        public static class FollowDtoInner { // Inner class unused if utilizing separate DTOs, but kept if needed
                private Long userId;
                private String nickname;
                private String email;
        }

        @Transactional
        public void deleteAllFollowsByUser(Long userId) {
                Users user = userRepository.findById(userId).orElseThrow();
                followRepository.deleteByFollower(user);
                followRepository.deleteByFollowing(user);
        }
}
