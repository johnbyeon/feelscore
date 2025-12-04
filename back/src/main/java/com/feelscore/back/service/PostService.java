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

        return Response.from(post);
    }

    public Response getPostById(Long postId) {
        Post post = postRepository.findByIdWithAll(postId)
                .orElseThrow(() -> new NoSuchElementException("Post not found with id: " + postId));
        return Response.from(post);
    }

    public Page<ListResponse> getPostsByCategory(Long categoryId, Pageable pageable) {
        Page<Post> posts = postRepository.findByCategory_IdAndStatus(categoryId, PostStatus.NORMAL, pageable);
        return posts.map(ListResponse::from);
    }

    public Page<ListResponse> getPostsByUser(Long userId, Pageable pageable) {
        Page<Object[]> results = postRepository.findByUsers_IdAndStatusWithEmotion(userId, PostStatus.NORMAL, pageable);
        return results.map(result -> {
            Post post = (Post) result[0];
            Object emotionObj = result[1];
            String emotion = (emotionObj != null) ? emotionObj.toString() : null;
            return ListResponse.from(post, emotion);
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

        post.updateContent(request.getContent()); // Post 엔티티에 updateContent 메서드 필요
        post.updateCategory(category); // Post 엔티티에 updateCategory 메서드 필요

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
}
