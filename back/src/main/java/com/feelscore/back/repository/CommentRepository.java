package com.feelscore.back.repository;

import com.feelscore.back.entity.Comment;
import com.feelscore.back.entity.Post;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

import com.feelscore.back.dto.CommentCountDto;
import org.springframework.data.jpa.repository.Query;

public interface CommentRepository extends JpaRepository<Comment, Long> {
    List<Comment> findByPostOrderByCreatedAtAsc(Post post);

    long countByPost(Post post);

    List<Comment> findAllByUsers(com.feelscore.back.entity.Users users);

    void deleteAllByPost(Post post);

    @Query("SELECT new com.feelscore.back.dto.CommentCountDto(p.category.id, COUNT(c)) " +
            "FROM Comment c JOIN c.post p " +
            "WHERE p.status = com.feelscore.back.entity.PostStatus.NORMAL " +
            "GROUP BY p.category.id")
    List<CommentCountDto> countCommentsGroupByCategory();
}
