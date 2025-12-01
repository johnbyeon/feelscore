package com.feelscore.back.service;

import com.feelscore.back.entity.Post;
import com.feelscore.back.entity.PostView;
import com.feelscore.back.entity.Users;
import com.feelscore.back.repository.PostRepository;
import com.feelscore.back.repository.PostViewRepository;
import com.feelscore.back.repository.UserRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class PostViewServiceTest {

    @InjectMocks
    private PostViewService postViewService;

    @Mock
    private PostViewRepository postViewRepository;

    @Mock
    private PostRepository postRepository;

    @Mock
    private UserRepository userRepository;

    @Test
    @DisplayName("조회수를 증가시킨다 (첫 조회)")
    void increaseViewCount_FirstTime() {
        // given
        Long postId = 1L;
        Long userId = 1L;
        String ipAddress = "127.0.0.1";

        Post post = new Post(postId);
        Users user = Users.builder().email("test@test.com").build();

        given(postRepository.findById(postId)).willReturn(Optional.of(post));
        given(userRepository.findById(userId)).willReturn(Optional.of(user));
        given(postViewRepository.existsByPostAndUsersAndCreatedAtAfter(eq(post), eq(user), any(LocalDateTime.class)))
                .willReturn(false);

        // when
        postViewService.increaseViewCount(postId, userId, ipAddress);

        // then
        verify(postViewRepository).save(any(PostView.class));
    }

    @Test
    @DisplayName("24시간 내 중복 조회는 무시한다")
    void increaseViewCount_Duplicate() {
        // given
        Long postId = 1L;
        Long userId = 1L;
        String ipAddress = "127.0.0.1";

        Post post = new Post(postId);
        Users user = Users.builder().email("test@test.com").build();

        given(postRepository.findById(postId)).willReturn(Optional.of(post));
        given(userRepository.findById(userId)).willReturn(Optional.of(user));
        given(postViewRepository.existsByPostAndUsersAndCreatedAtAfter(eq(post), eq(user), any(LocalDateTime.class)))
                .willReturn(true);

        // when
        postViewService.increaseViewCount(postId, userId, ipAddress);

        // then
        verify(postViewRepository, never()).save(any(PostView.class));
    }
}
