package com.feelscore.back.repository;

import com.feelscore.back.entity.Post;
import com.feelscore.back.entity.PostView;
import com.feelscore.back.entity.Users;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;

public interface PostViewRepository extends JpaRepository<PostView, Long> {

    long countByPostId(Long postId);

    boolean existsByPostAndUsersAndCreatedAtAfter(Post post, Users users, LocalDateTime createdAt);

    boolean existsByPostAndIpAddressAndCreatedAtAfter(Post post, String ipAddress, LocalDateTime createdAt);
}
