package com.feelscore.back.repository;

import com.feelscore.back.entity.Post;
import com.feelscore.back.entity.PostStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PostRepository extends JpaRepository<Post, Long> {

        // 특정 카테고리의 게시글 목록 조회 (페이징)
        Page<Post> findByCategory_Id(Long categoryId, Pageable pageable);

        // 특정 카테고리의 정상 게시글만 조회
        Page<Post> findByCategory_IdAndStatus(Long categoryId, PostStatus status, Pageable pageable);

        // 특정 사용자의 게시글 목록 조회 (감정 분석 결과 포함)
        @Query("SELECT p, pe.dominantEmotion FROM Post p LEFT JOIN PostEmotion pe ON p.id = pe.post.id WHERE p.users.id = :userId AND p.status = :status")
        Page<Object[]> findByUsers_IdAndStatusWithEmotion(@Param("userId") Long userId,
                        @Param("status") PostStatus status,
                        Pageable pageable);

        // 특정 사용자의 게시글 목록 조회 (기존 메서드 유지)
        Page<Post> findByUsers_Id(Long userId, Pageable pageable);

        // 특정 사용자의 정상 게시글만 조회 (기존 메서드 유지)
        Page<Post> findByUsers_IdAndStatus(Long userId, PostStatus status, Pageable pageable);

        // 게시글과 작성자 정보 함께 조회 (Fetch Join)
        @Query("SELECT p FROM Post p JOIN FETCH p.users WHERE p.id = :id")
        Optional<Post> findByIdWithUser(@Param("id") Long id);

        // 게시글과 카테고리 정보 함께 조회 (Fetch Join)
        @Query("SELECT p FROM Post p JOIN FETCH p.category WHERE p.id = :id")
        Optional<Post> findByIdWithCategory(@Param("id") Long id);

        // 게시글, 작성자, 카테고리 모두 함께 조회 (Fetch Join)
        @Query("SELECT p FROM Post p " +
                        "JOIN FETCH p.users " +
                        "JOIN FETCH p.category " +
                        "WHERE p.id = :id")
        Optional<Post> findByIdWithAll(@Param("id") Long id);

        // 특정 상태의 게시글 개수 조회
        long countByStatus(PostStatus status);

        // 특정 카테고리의 게시글 개수 조회
        long countByCategory_Id(Long categoryId);

        // 정상 게시글 전체 조회 (페이징)
        Page<Post> findByStatus(PostStatus status, Pageable pageable);

        // 최근 게시글 조회 (생성일 기준 내림차순, 페이징 적용)
        Page<Post> findByStatusOrderByCreatedAtDesc(PostStatus status, Pageable pageable);

        // 여러 카테고리 ID에 속한 게시글 조회 (감정 분석 결과 포함)
        @Query("SELECT p, pe.dominantEmotion FROM Post p LEFT JOIN PostEmotion pe ON p.id = pe.post.id WHERE p.category.id IN :categoryIds AND p.status = :status")
        Page<Object[]> findByCategory_IdInAndStatusWithEmotion(@Param("categoryIds") List<Long> categoryIds,
                        @Param("status") PostStatus status, Pageable pageable);
}