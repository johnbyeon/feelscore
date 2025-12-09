package com.feelscore.back.repository;

import com.feelscore.back.entity.Comment;
import com.feelscore.back.entity.Post;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface CommentRepository extends JpaRepository<Comment, Long> {
    List<Comment> findByPostOrderByCreatedAtAsc(Post post);

    long countByPost(Post post);
}
