package com.feelscore.back.repository;

import com.feelscore.back.entity.EmotionType;
import com.feelscore.back.entity.Post;
import com.feelscore.back.entity.PostReaction;
import com.feelscore.back.entity.Users;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface PostReactionRepository extends JpaRepository<PostReaction, Long> {
    Optional<PostReaction> findByPostAndUsers(Post post, Users users); // Corrected 'User' to 'Users' based on entity
                                                                       // name

    long countByPostAndEmotionType(Post post, EmotionType emotionType);

    // Efficiently count all reactions for a post grouped by emotion type
    @Query("SELECT r.emotionType, COUNT(r) FROM PostReaction r WHERE r.post = :post GROUP BY r.emotionType")
    List<Object[]> countReactionsByPost(@Param("post") Post post);

    void deleteByUsers(Users users);

    void deleteAllByPost(Post post);
}
