package com.feelscore.back.service;

import com.feelscore.back.entity.Follow;
import com.feelscore.back.entity.Users;
import com.feelscore.back.repository.FollowRepository;
import com.feelscore.back.repository.UserRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class FollowServiceTest {

    @InjectMocks
    private FollowService followService;

    @Mock
    private FollowRepository followRepository;

    @Mock
    private UserRepository userRepository;

    @Test
    @DisplayName("사용자를 팔로우한다")
    void follow() {
        // given
        Long followerId = 1L;
        Long followingId = 2L;

        Users follower = Users.builder().email("follower@test.com").build();
        Users following = Users.builder().email("following@test.com").build();

        given(userRepository.findById(followerId)).willReturn(Optional.of(follower));
        given(userRepository.findById(followingId)).willReturn(Optional.of(following));
        given(followRepository.existsByFollowerAndFollowing(follower, following)).willReturn(false);

        // when
        followService.follow(followerId, followingId);

        // then
        verify(followRepository).save(any(Follow.class));
    }

    @Test
    @DisplayName("이미 팔로우한 경우 예외 발생")
    void follow_Duplicate() {
        // given
        Long followerId = 1L;
        Long followingId = 2L;

        Users follower = Users.builder().email("follower@test.com").build();
        Users following = Users.builder().email("following@test.com").build();

        given(userRepository.findById(followerId)).willReturn(Optional.of(follower));
        given(userRepository.findById(followingId)).willReturn(Optional.of(following));
        given(followRepository.existsByFollowerAndFollowing(follower, following)).willReturn(true);

        // when & then
        assertThatThrownBy(() -> followService.follow(followerId, followingId))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("이미 팔로우 중입니다.");
    }

    @Test
    @DisplayName("자기 자신을 팔로우할 수 없다")
    void follow_Self() {
        // given
        Long userId = 1L;

        // when & then
        assertThatThrownBy(() -> followService.follow(userId, userId))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("자기 자신을 팔로우할 수 없습니다.");
    }
}
