package com.feelscore.back.service;

import com.feelscore.back.dto.CommentDto;
import com.feelscore.back.entity.Comment;
import com.feelscore.back.entity.Post;
import com.feelscore.back.entity.Users;
import com.feelscore.back.repository.CommentRepository;
import com.feelscore.back.repository.PostRepository;
import com.feelscore.back.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.HashMap;
import java.util.Optional;
import java.util.NoSuchElementException;
import java.util.stream.Collectors;
import com.feelscore.back.repository.CommentReactionRepository;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CommentService {

        private final CommentRepository commentRepository;
        private final CommentReactionRepository commentReactionRepository;
        private final PostRepository postRepository;
        private final UserRepository userRepository;
        private final NotificationProducer notificationProducer; // 🔹 알림 발송자 주입

        @Transactional
        public CommentDto.Response createComment(Long postId, Long userId, String content) {
                Post post = postRepository.findById(postId)
                                .orElseThrow(() -> new NoSuchElementException("Post not found id: " + postId));
                Users user = userRepository.findById(userId)
                                .orElseThrow(() -> new NoSuchElementException("User not found id: " + userId));

                Comment comment = Comment.builder()
                                .post(post)
                                .users(user)
                                .content(content)
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

                return CommentDto.Response.from(comment);
        }

        public List<CommentDto.Response> getComments(Long postId, Long userId) {
                Post post = postRepository.findById(postId)
                                .orElseThrow(() -> new NoSuchElementException("Post not found id: " + postId));

                List<Comment> comments = commentRepository.findByPostOrderByCreatedAtAsc(post);

                return comments.stream().map(comment -> {
                        List<Object[]> reactionObjs = commentReactionRepository.countReactionsByComment(comment);
                        Map<com.feelscore.back.entity.EmotionType, Long> reactionCounts = new HashMap<>();
                        for (Object[] row : reactionObjs) {
                                reactionCounts.put((com.feelscore.back.entity.EmotionType) row[0], (Long) row[1]);
                        }

                        com.feelscore.back.entity.EmotionType myReaction = null;
                        if (userId != null) {
                                Users user = userRepository.findById(userId).orElse(null);
                                if (user != null) {
                                        myReaction = commentReactionRepository.findByCommentAndUsers(comment, user)
                                                        .map(com.feelscore.back.entity.CommentReaction::getEmotionType)
                                                        .orElse(null);
                                }
                        }

                        return CommentDto.Response.from(comment, reactionCounts, myReaction);
                }).collect(Collectors.toList());
        }

        @Transactional
        public void toggleCommentReaction(Long commentId, Long userId,
                        com.feelscore.back.entity.EmotionType emotionType) {
                Comment comment = commentRepository.findById(commentId)
                                .orElseThrow(() -> new NoSuchElementException("Comment not found id: " + commentId));
                Users user = userRepository.findById(userId)
                                .orElseThrow(() -> new NoSuchElementException("User not found id: " + userId));

                Optional<com.feelscore.back.entity.CommentReaction> existingReaction = commentReactionRepository
                                .findByCommentAndUsers(comment, user);

                if (existingReaction.isPresent()) {
                        com.feelscore.back.entity.CommentReaction reaction = existingReaction.get();
                        if (reaction.getEmotionType() == emotionType) {
                                commentReactionRepository.delete(reaction);
                        } else {
                                reaction.updateEmotion(emotionType);
                        }
                } else {
                        com.feelscore.back.entity.CommentReaction reaction = com.feelscore.back.entity.CommentReaction
                                        .builder()
                                        .comment(comment)
                                        .users(user)
                                        .emotionType(emotionType)
                                        .build();
                        commentReactionRepository.save(reaction);
                }
        }
}
