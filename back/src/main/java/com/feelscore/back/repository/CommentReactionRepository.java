package com.feelscore.back.repository;

import com.feelscore.back.entity.Comment;
import com.feelscore.back.entity.CommentReaction;
import com.feelscore.back.entity.Users;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface CommentReactionRepository extends JpaRepository<CommentReaction, Long> {

    Optional<CommentReaction> findByCommentAndUsers(Comment comment, Users users);
}
