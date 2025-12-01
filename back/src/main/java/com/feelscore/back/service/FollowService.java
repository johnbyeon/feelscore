package com.feelscore.back.service;

import com.feelscore.back.entity.Follow;
import com.feelscore.back.entity.Users;
import com.feelscore.back.repository.FollowRepository;
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

    /**
     * 팔로우 하기
     */
    @Transactional
    public void follow(Long followerId, Long followingId) {
        if (followerId.equals(followingId)) {
            throw new IllegalArgumentException("자기 자신을 팔로우할 수 없습니다.");
        }

        Users follower = userRepository.findById(followerId)
                .orElseThrow(() -> new NoSuchElementException("Follower not found with id: " + followerId));
        Users following = userRepository.findById(followingId)
                .orElseThrow(() -> new NoSuchElementException("User to follow not found with id: " + followingId));

        if (followRepository.existsByFollowerAndFollowing(follower, following)) {
            throw new IllegalStateException("이미 팔로우 중입니다.");
        }

        Follow follow = Follow.builder()
                .follower(follower)
                .following(following)
                .build();

        followRepository.save(follow);
    }

    /**
     * 언팔로우 하기
     */
    @Transactional
    public void unfollow(Long followerId, Long followingId) {
        Users follower = userRepository.findById(followerId)
                .orElseThrow(() -> new NoSuchElementException("Follower not found with id: " + followerId));
        Users following = userRepository.findById(followingId)
                .orElseThrow(() -> new NoSuchElementException("User to unfollow not found with id: " + followingId));

        followRepository.deleteByFollowerAndFollowing(follower, following);
    }

    /**
     * 팔로워 목록 조회 (나를 팔로우 하는 사람들)
     */
    public List<FollowDto> getFollowers(Long userId) {
        Users user = userRepository.findById(userId)
                .orElseThrow(() -> new NoSuchElementException("User not found with id: " + userId));

        return followRepository.findByFollowing(user).stream()
                .map(follow -> FollowDto.from(follow.getFollower()))
                .collect(Collectors.toList());
    }

    /**
     * 팔로잉 목록 조회 (내가 팔로우 하는 사람들)
     */
    public List<FollowDto> getFollowings(Long userId) {
        Users user = userRepository.findById(userId)
                .orElseThrow(() -> new NoSuchElementException("User not found with id: " + userId));

        return followRepository.findByFollower(user).stream()
                .map(follow -> FollowDto.from(follow.getFollowing()))
                .collect(Collectors.toList());
    }

    @Getter
    @Builder
    public static class FollowDto {
        private Long userId;
        private String nickname;
        private String email;

        public static FollowDto from(Users user) {
            return FollowDto.builder()
                    .userId(user.getId())
                    .nickname(user.getNickname())
                    .email(user.getEmail())
                    .build();
        }
    }
}
