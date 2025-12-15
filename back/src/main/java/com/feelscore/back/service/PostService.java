package com.feelscore.back.service;

import com.feelscore.back.entity.Category;
import com.feelscore.back.entity.Post;
import com.feelscore.back.entity.PostStatus;
import com.feelscore.back.entity.Users;
import com.feelscore.back.repository.CategoryRepository;
import com.feelscore.back.repository.PostRepository;
import com.feelscore.back.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.NoSuchElementException;

import static com.feelscore.back.dto.PostDto.*;
import jakarta.validation.Valid;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class PostService {

    private final PostRepository postRepository;
    private final UserRepository userRepository;
    private final CategoryRepository categoryRepository;
    private final PostAnalysisProducer postAnalysisProducer;
    private final com.feelscore.back.repository.PostReactionRepository postReactionRepository;
    private final com.feelscore.back.repository.CommentRepository commentRepository;
    private final com.feelscore.back.repository.PostEmotionRepository postEmotionRepository;
    private final S3Service s3Service; // Inject S3Service
    private final CommentService commentService;
    private final MentionService mentionService;

    @Transactional
    public Response createPost(@Valid CreateRequest request, Long userId) {
        Users user = userRepository.findById(userId)
                .orElseThrow(() -> new NoSuchElementException("User not found with id: " + userId));
        Category category = categoryRepository.findById(request.getCategoryId())
                .orElseThrow(
                        () -> new NoSuchElementException("Category not found with id: " + request.getCategoryId()));

        Post post = request.toEntity(user, category);
        postRepository.save(post);

        // RabbitMQ로 분석 요청 메시지 전송
        try {
            postAnalysisProducer.sendAnalysisEvent(post.getId(), post.getContent());
        } catch (Exception e) {
            // 메시지 전송 실패가 게시글 생성을 막지 않도록 로그만 남김 (필요 시 재시도 로직 추가 가능)
            // log.error("Failed to send analysis event", e);
            System.err.println("Failed to send analysis event: " + e.getMessage());
        }

        // @멘션 처리
        mentionService.processMentionsForPost(post, user, post.getContent());

        return Response.from(post);
    }

    public Response getPostById(Long postId) {
        Post post = postRepository.findByIdWithAll(postId)
                .orElseThrow(() -> new NoSuchElementException("Post not found with id: " + postId));

        Long commentCount = commentRepository.countByPost(post);

        List<Object[]> reactionObjs = postReactionRepository.countReactionsByPost(post);
        java.util.Map<com.feelscore.back.entity.EmotionType, Long> reactionCounts = new java.util.HashMap<>();
        for (Object[] row : reactionObjs) {
            com.feelscore.back.entity.EmotionType type = (com.feelscore.back.entity.EmotionType) row[0];
            Long count = (row[1] instanceof Number) ? ((Number) row[1]).longValue() : 0L;
            reactionCounts.put(type, count);
        }

        return Response.from(post, commentCount, reactionCounts);
    }

    public Page<ListResponse> getPostsByCategory(Long categoryId, Pageable pageable) {
        // 1. 해당 카테고리 및 하위 카테고리 ID 목록 수집
        Category category = categoryRepository.findById(categoryId)
                .orElseThrow(() -> new NoSuchElementException("Category not found with id: " + categoryId));

        List<Long> categoryIds = new ArrayList<>();
        categoryIds.add(categoryId);
        for (Category child : category.getChildren()) {
            categoryIds.add(child.getId());
        }

        // 2. 게시글 조회 - 리액션 수 기준 정렬 (내림차순), 동점시 content 가나다순
        Page<Object[]> results = postRepository.findByCategoryOrderByReactionCount(categoryIds, PostStatus.NORMAL,
                pageable);

        return results.map(result -> {
            Post post = (Post) result[0];
            Object emotionObj = result[1];
            // result[2]는 reactionCount (쿼리에서 가져온 값)
            String emotion = (emotionObj != null) ? emotionObj.toString() : null;
            Long commentCount = commentRepository.countByPost(post);
            List<Object[]> reactionObjs = postReactionRepository.countReactionsByPost(post);
            java.util.Map<com.feelscore.back.entity.EmotionType, Long> reactionCounts = new java.util.HashMap<>();
            for (Object[] row : reactionObjs) {
                com.feelscore.back.entity.EmotionType type = (com.feelscore.back.entity.EmotionType) row[0];
                Long count = (row[1] instanceof Number) ? ((Number) row[1]).longValue() : 0L;
                reactionCounts.put(type, count);
            }

            return ListResponse.from(post, emotion, commentCount, reactionCounts);
        });
    }

    public Page<ListResponse> getPostsByUser(Long userId, Pageable pageable) {
        Page<Object[]> results = postRepository.findByUsers_IdAndStatusWithEmotion(userId, PostStatus.NORMAL, pageable);
        return results.map(result -> {
            Post post = (Post) result[0];
            Object emotionObj = result[1];
            String emotion = (emotionObj != null) ? emotionObj.toString() : null;
            Long commentCount = commentRepository.countByPost(post);
            List<Object[]> reactionObjs = postReactionRepository.countReactionsByPost(post);
            java.util.Map<com.feelscore.back.entity.EmotionType, Long> reactionCounts = new java.util.HashMap<>();
            for (Object[] row : reactionObjs) {
                com.feelscore.back.entity.EmotionType type = (com.feelscore.back.entity.EmotionType) row[0];
                Long count = (row[1] instanceof Number) ? ((Number) row[1]).longValue() : 0L;
                reactionCounts.put(type, count);
            }

            return ListResponse.from(post, emotion, commentCount, reactionCounts);
        });
    }

    public Page<ListResponse> getPostsByEmotion(com.feelscore.back.entity.EmotionType emotionType, Pageable pageable) {
        Page<Object[]> results = postRepository.findByEmotion(emotionType, PostStatus.NORMAL, pageable);
        return results.map(result -> {
            Post post = (Post) result[0];
            Object emotionObj = result[1];
            String emotion = (emotionObj != null) ? emotionObj.toString() : null;
            Long commentCount = commentRepository.countByPost(post);
            List<Object[]> reactionObjs = postReactionRepository.countReactionsByPost(post);
            java.util.Map<com.feelscore.back.entity.EmotionType, Long> reactionCounts = new java.util.HashMap<>();
            for (Object[] row : reactionObjs) {
                com.feelscore.back.entity.EmotionType type = (com.feelscore.back.entity.EmotionType) row[0];
                Long count = (row[1] instanceof Number) ? ((Number) row[1]).longValue() : 0L;
                reactionCounts.put(type, count);
            }

            return ListResponse.from(post, emotion, commentCount, reactionCounts);
        });
    }

    @Transactional
    public Response updatePost(Long postId, @Valid UpdateRequest request, Long userId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new NoSuchElementException("Post not found with id: " + postId));

        if (!post.getUsers().getId().equals(userId)) {
            throw new IllegalArgumentException("User does not have permission to update this post.");
        }

        Category category = categoryRepository.findById(request.getCategoryId())
                .orElseThrow(
                        () -> new NoSuchElementException("Category not found with id: " + request.getCategoryId()));

        // 내용이 변경되었는지 확인
        boolean contentChanged = !post.getContent().equals(request.getContent());

        post.updateContent(request.getContent());
        post.updateCategory(category);

        // 이미지 URL 업데이트
        if (request.getImageUrl() != null) {
            post.updateImageUrl(request.getImageUrl());
        }

        // 내용이 변경되었으면 감정 재분석 요청
        if (contentChanged) {
            try {
                postAnalysisProducer.sendAnalysisEvent(post.getId(), post.getContent());
            } catch (Exception e) {
                System.err.println("Failed to send re-analysis event: " + e.getMessage());
            }
        }

        return Response.from(post);
    }

    @Transactional
    public void deletePost(Long postId, Long userId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new NoSuchElementException("Post not found with id: " + postId));

        if (!post.getUsers().getId().equals(userId)) {
            throw new IllegalArgumentException("User does not have permission to delete this post.");
        }

        post.setStatus(PostStatus.DELETED); // Post 엔티티에 setStatus 메서드 필요
    }

    @Transactional
    public void deleteAllPostsByUser(Long userId) {
        // 1. 유저가 작성한 모든 게시글 조회
        List<Post> posts = postRepository.findAllByUsers_Id(userId);

        for (Post post : posts) {
            // 2. 게시글에 달린 리액션 삭제
            postReactionRepository.deleteAllByPost(post);

            // 3. 게시글에 달린 댓글 삭제 (댓글 리액션 포함)
            commentService.deleteAllCommentsByPost(post);

            // 4. 감정 분석 데이터 삭제 (FK 제약조건 방지)
            postEmotionRepository.deleteByPost(post);

            // 5. S3 이미지 삭제 (이미지가 있는 경우)
            if (post.getImageUrl() != null && !post.getImageUrl().isBlank()) {
                try {
                    s3Service.deleteFile(post.getImageUrl());
                } catch (Exception e) {
                    System.err.println("Failed to delete post image from S3: " + e.getMessage());
                }
            }

            // 6. 게시글 삭제 (Hard Delete)
        }
    }

    /**
     * 키워드로 게시글 검색 (띄어쓰기로 구분된 키워드 중 하나라도 포함되면 반환)
     */
    public Page<ListResponse> searchPosts(String keywords, Pageable pageable) {
        if (keywords == null || keywords.trim().isEmpty()) {
            return Page.empty(pageable);
        }

        // 띄어쓰기로 키워드 분리
        String[] keywordArray = keywords.trim().split("\\s+");

        // 첫 번째 키워드로 검색 시작
        Page<Object[]> results = postRepository.searchByKeyword(keywordArray[0], PostStatus.NORMAL, pageable);

        return results.map(result -> {
            Post post = (Post) result[0];
            Object emotionObj = result[1];
            String emotion = (emotionObj != null) ? emotionObj.toString() : null;
            Long commentCount = commentRepository.countByPost(post);
            List<Object[]> reactionObjs = postReactionRepository.countReactionsByPost(post);
            java.util.Map<com.feelscore.back.entity.EmotionType, Long> reactionCounts = new java.util.HashMap<>();
            for (Object[] row : reactionObjs) {
                com.feelscore.back.entity.EmotionType type = (com.feelscore.back.entity.EmotionType) row[0];
                Long count = (row[1] instanceof Number) ? ((Number) row[1]).longValue() : 0L;
                reactionCounts.put(type, count);
            }

            return ListResponse.from(post, emotion, commentCount, reactionCounts);
        });
    }

    /**
     * 단일 게시글을 ListResponse로 변환 (외부 서비스용)
     */
    public ListResponse getPostListResponse(Post post, Long currentUserId) {
        // 감정 정보 조회
        String emotion = postEmotionRepository.findByPost(post)
                .map(pe -> pe.getDominantEmotion().name())
                .orElse(null);

        Long commentCount = commentRepository.countByPost(post);

        List<Object[]> reactionObjs = postReactionRepository.countReactionsByPost(post);
        java.util.Map<com.feelscore.back.entity.EmotionType, Long> reactionCounts = new java.util.HashMap<>();
        for (Object[] row : reactionObjs) {
            com.feelscore.back.entity.EmotionType type = (com.feelscore.back.entity.EmotionType) row[0];
            Long count = (row[1] instanceof Number) ? ((Number) row[1]).longValue() : 0L;
            reactionCounts.put(type, count);
        }

        return ListResponse.from(post, emotion, commentCount, reactionCounts);
    }
}
