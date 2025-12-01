package com.feelscore.back.service;

import com.feelscore.back.entity.Post;
import com.feelscore.back.entity.PostView;
import com.feelscore.back.entity.Users;
import com.feelscore.back.repository.PostRepository;
import com.feelscore.back.repository.PostViewRepository;
import com.feelscore.back.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.NoSuchElementException;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class PostViewService {

    private final PostViewRepository postViewRepository;
    private final PostRepository postRepository;
    private final UserRepository userRepository;

    /**
     * 조회수 증가 (중복 조회 방지 로직 포함)
     * - userId가 있으면 userId 기준, 없으면 ipAddress 기준으로 24시간 내 중복 체크
     */
    @Transactional
    public void increaseViewCount(Long postId, Long userId, String ipAddress) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new NoSuchElementException("Post not found with id: " + postId));

        Users user = null;
        if (userId != null) {
            user = userRepository.findById(userId).orElse(null);
        }

        // 24시간 이내 조회 기록 확인
        LocalDateTime yesterday = LocalDateTime.now().minusHours(24);
        boolean alreadyViewed;

        if (user != null) {
            alreadyViewed = postViewRepository.existsByPostAndUsersAndCreatedAtAfter(post, user, yesterday);
        } else {
            alreadyViewed = postViewRepository.existsByPostAndIpAddressAndCreatedAtAfter(post, ipAddress, yesterday);
        }

        if (!alreadyViewed) {
            PostView postView = PostView.builder()
                    .post(post)
                    .users(user)
                    .ipAddress(ipAddress)
                    .build();
            postViewRepository.save(postView);
        }
    }

    /**
     * 게시글의 총 조회수 조회
     */
    public long getViewCount(Long postId) {
        return postViewRepository.countByPostId(postId);
    }
}
