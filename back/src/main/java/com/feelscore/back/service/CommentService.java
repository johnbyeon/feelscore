package com.feelscore.back.service;

import com.feelscore.back.entity.*;
import com.feelscore.back.repository.CommentReactionRepository;
import com.feelscore.back.repository.CommentRepository;
import com.feelscore.back.repository.PostRepository;
import com.feelscore.back.repository.UserRepository;
import lombok.Builder;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CommentService {

        private final CommentRepository commentRepository;
        private final CommentReactionRepository commentReactionRepository;
        private final PostRepository postRepository;
        private final UserRepository userRepository;
        private final NotificationProducer notificationProducer; // 🔹 알림 발송자 주입

        /**
         * 댓글 작성
         */
        @Transactional
        public Long createComment(Long postId, Long userId, String content, EmotionType emotion) {
                Post post = postRepository.findById(postId)
                                .orElseThrow(() -> new NoSuchElementException("Post not found with id: " + postId));
                Users user = userRepository.findById(userId)
                                .orElseThrow(() -> new NoSuchElementException("User not found with id: " + userId));

                Comment comment = Comment.builder()
                                .content(content)
                                .emotion(emotion)
                                .post(post)
                                .users(user)
                                .build();

                commentRepository.save(comment);

                // 🔹 알림 발송 로직 (내 글에 내가 쓴 댓글은 알림 X)
                Users postWriter = post.getUsers();
                if (!postWriter.getId().equals(userId) && postWriter.getFcmToken() != null) {
                        com.feelscore.back.dto.FCMRequestDto fcmRequest = new com.feelscore.back.dto.FCMRequestDto();
                        fcmRequest.setTargetToken(postWriter.getFcmToken());
                        fcmRequest.setTitle("새로운 댓글이 달렸습니다!");
                        fcmRequest.setBody(user.getNickname() + "님이 댓글을 남겼습니다: " + content);

                        notificationProducer.sendNotification(fcmRequest);
                }

                return comment.getId();
        }

        /**
         * 댓글 반응 추가/수정
         */
        @Transactional
        public void addReaction(Long commentId, Long userId, EmotionType emotion) {
                Comment comment = commentRepository.findById(commentId)
                                .orElseThrow(() -> new NoSuchElementException(
                                                "Comment not found with id: " + commentId));
                Users user = userRepository.findById(userId)
                                .orElseThrow(() -> new NoSuchElementException("User not found with id: " + userId));

                CommentReaction reaction = commentReactionRepository.findByCommentAndUsers(comment, user)
                                .orElse(null);

                if (reaction == null) {
                        reaction = CommentReaction.builder()
                                        .comment(comment)
                                        .users(user)
                                        .emotion(emotion)
                                        .build();
                        commentReactionRepository.save(reaction);
                } else {
                        reaction.updateEmotion(emotion);
                }
        }

        /**
         * 댓글 반응 삭제
         */
        @Transactional
        public void removeReaction(Long commentId, Long userId) {
                Comment comment = commentRepository.findById(commentId)
                                .orElseThrow(() -> new NoSuchElementException(
                                                "Comment not found with id: " + commentId));
                Users user = userRepository.findById(userId)
                                .orElseThrow(() -> new NoSuchElementException("User not found with id: " + userId));

                CommentReaction reaction = commentReactionRepository.findByCommentAndUsers(comment, user)
                                .orElseThrow(() -> new NoSuchElementException("Reaction not found"));

                commentReactionRepository.delete(reaction);
        }

        /**
         * 게시글의 댓글 목록 조회 (반응 집계 포함)
         */
        public List<CommentResponse> getCommentsByPost(Long postId) {
                List<Comment> comments = commentRepository.findByPostId(postId);

                return comments.stream()
                                .map(this::toResponse)
                                .collect(Collectors.toList());
        }

        private CommentResponse toResponse(Comment comment) {
                // 반응 집계
                Map<EmotionType, Long> reactionCounts = comment.getReactions().stream()
                                .collect(Collectors.groupingBy(CommentReaction::getEmotion, Collectors.counting()));

                return CommentResponse.builder()
                                .id(comment.getId())
                                .content(comment.getContent())
                                .emotion(comment.getEmotion())
                                .writerNickname(comment.getUsers().getNickname())
                                .createdAt(comment.getCreatedAt())
                                .reactionCounts(reactionCounts)
                                .build();
        }

        @Getter
        @Builder
        public static class CommentResponse {
                private Long id;
                private String content;
                private EmotionType emotion;
                private String writerNickname;
                private LocalDateTime createdAt;
                private Map<EmotionType, Long> reactionCounts;
        }
}
