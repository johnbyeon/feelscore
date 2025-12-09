package com.feelscore.back.repository;

import com.feelscore.back.entity.Comment;
import com.feelscore.back.entity.CommentReaction;
import com.feelscore.back.entity.EmotionType;
import com.feelscore.back.entity.Users;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface CommentReactionRepository extends JpaRepository<CommentReaction, Long> {
    Optional<CommentReaction> findByCommentAndUsers(Comment comment, Users users);

    @Query("SELECT r.emotionType, COUNT(r) FROM CommentReaction r WHERE r.comment = :comment GROUP BY r.emotionType")
    List<Object[]> countReactionsByComment(@Param("comment") Comment comment);
}
