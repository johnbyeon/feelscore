package com.feelscore.back.repository;

import com.feelscore.back.entity.Mention;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface MentionRepository extends JpaRepository<Mention, Long> {

    /**
     * 특정 유저가 태그된 멘션 목록 조회 (최신순)
     */
    List<Mention> findByMentionedUserIdOrderByCreatedAtDesc(Long mentionedUserId);

    /**
     * 특정 게시글의 멘션 목록 조회
     */
    List<Mention> findByPostId(Long postId);

    /**
     * 특정 댓글의 멘션 목록 조회
     */
    List<Mention> findByCommentId(Long commentId);

    /**
     * 특정 게시글에서 특정 유저가 멘션되었는지 확인
     */
    boolean existsByPostIdAndMentionedUserId(Long postId, Long mentionedUserId);

    /**
     * 게시글 삭제 시 관련 멘션 삭제
     */
    void deleteByPostId(Long postId);

    /**
     * 댓글 삭제 시 관련 멘션 삭제
     */
    void deleteByCommentId(Long commentId);

    /**
     * 유저가 태그된 고유한 게시글 ID 목록 (중복 제거)
     */
    @Query("SELECT DISTINCT m.post.id FROM Mention m WHERE m.mentionedUser.id = :userId AND m.post IS NOT NULL ORDER BY m.post.id DESC")
    List<Long> findDistinctPostIdsByMentionedUserId(@Param("userId") Long userId);
}
