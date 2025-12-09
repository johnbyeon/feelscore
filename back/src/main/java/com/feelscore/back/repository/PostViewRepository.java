package com.feelscore.back.repository;

import com.feelscore.back.entity.Post;
import com.feelscore.back.entity.PostView;
import com.feelscore.back.entity.Users;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.Optional;

public interface PostViewRepository extends JpaRepository<PostView, Long> {

    boolean existsByPostAndUsers(Post post, Users users);

    // IP based check for anonymous/all users logic if needed,
    // but user requirements imply logged in users mostly.
    // We will support checking duplications.

    boolean existsByPostAndIpAddressAndCreatedAtAfter(Post post, String ipAddress, LocalDateTime cutoff);

    boolean existsByPostAndUsersAndCreatedAtAfter(Post post, Users users, LocalDateTime createdAt);

    long countByPostId(Long postId);

    long countByPost(Post post);
}
