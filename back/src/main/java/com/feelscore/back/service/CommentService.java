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
        private final MentionService mentionService; // @멘션 서비스

        @Transactional
        public CommentDto.Response createComment(Long postId, Long userId, String content, Long parentId) {
                Post post = postRepository.findById(postId)
                                .orElseThrow(() -> new NoSuchElementException("Post not found id: " + postId));
                Users user = userRepository.findById(userId)
                                .orElseThrow(() -> new NoSuchElementException("User not found id: " + userId));

                Comment parent = null;
                if (parentId != null) {
                        parent = commentRepository.findById(parentId)
                                        .orElseThrow(() -> new NoSuchElementException(
                                                        "Parent comment not found id: " + parentId));
                }

                Comment comment = Comment.builder()
                                .post(post)
                                .users(user)
                                .content(content)
                                .parent(parent)
                                .build();

                commentRepository.save(comment);

                // 🔹 알림 발송 (내 글에 내가 쓴 댓글은 알림 X)
                // 답글인 경우 원댓글 작성자에게 알림? (Optional enhancement, sticking to post writer for now
                // or adding condition)
                // For MVP, keep post writer notification.
                try {
                        Users postWriter = post.getUsers();
                        if (postWriter != null && !postWriter.getId().equals(userId)) {
                                com.feelscore.back.dto.NotificationEventDto eventDto = com.feelscore.back.dto.NotificationEventDto
                                                .builder()
                                                .recipientId(postWriter.getId())
                                                .senderId(userId)
                                                .type(com.feelscore.back.entity.NotificationType.COMMENT)
                                                .relatedId(postId)
                                                .title("새로운 댓글이 달렸습니다!")
                                                .body(user.getNickname() + "님이 댓글을 남겼습니다: " + content)
                                                .relatedContentImageUrl(post.getImageUrl())
                                                .build();

                                notificationProducer.sendNotification(eventDto);
                        }
                        // 답글 알림 추가 (원댓글 작성자에게)
                        if (parent != null && !parent.getUsers().getId().equals(userId)) {
                                // Only notify if parent author is different from replier AND different from
                                // post writer (avoid duplicate if post writer == parent writer)
                                // Actually, simple check:
                                if (postWriter != null && !parent.getUsers().getId().equals(postWriter.getId())) {
                                        com.feelscore.back.dto.NotificationEventDto replyEvent = com.feelscore.back.dto.NotificationEventDto
                                                        .builder()
                                                        .recipientId(parent.getUsers().getId())
                                                        .senderId(userId)
                                                        .type(com.feelscore.back.entity.NotificationType.COMMENT) // Or
                                                                                                                  // new
                                                                                                                  // type
                                                                                                                  // REPLY?
                                                                                                                  // reuse
                                                                                                                  // COMMENT
                                                        .relatedId(postId)
                                                        .title("새로운 답글이 달렸습니다!")
                                                        .body(user.getNickname() + "님이 답글을 남겼습니다: " + content)
                                                        .relatedContentImageUrl(post.getImageUrl())
                                                        .build();
                                        notificationProducer.sendNotification(replyEvent);
                                }
                        }

                } catch (Exception e) {
                        System.err.println("Failed to send comment notification: " + e.getMessage());
                        e.printStackTrace();
                }

                // @멘션 처리
                mentionService.processMentionsForComment(comment, user, content);

                return CommentDto.Response.from(comment);
        }

        public List<CommentDto.Response> getComments(Long postId, Long userId) {
                Post post = postRepository.findById(postId)
                                .orElseThrow(() -> new NoSuchElementException("Post not found id: " + postId));

                List<Comment> comments = commentRepository.findByPostOrderByCreatedAtAsc(post);

                List<CommentDto.Response> allDtos = comments.stream().map(comment -> {
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

                // Build Hierarchy
                List<CommentDto.Response> roots = new java.util.ArrayList<>();
                Map<Long, CommentDto.Response> map = allDtos.stream()
                                .collect(Collectors.toMap(CommentDto.Response::getId, c -> c));

                for (CommentDto.Response dto : allDtos) {
                        if (dto.getParentId() != null) {
                                CommentDto.Response p = map.get(dto.getParentId());
                                if (p != null) {
                                        if (p.getChildren() == null) {
                                                // Should be initialized by default, but safe check or direct access
                                                // DTO builder initialized it?
                                                // In my DTO change I initialized it in `from`.
                                        }
                                        p.getChildren().add(dto);
                                } else {
                                        // Parent not found in list (maybe deleted?), treat as root or ignore?
                                        // Treat as root to be safe
                                        roots.add(dto);
                                }
                        } else {
                                roots.add(dto);
                        }
                }

                return roots;
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

                        // 🔹 알림 발송 (내 댓글에 내가 반응하면 알림 X)
                        try {
                                Users commentWriter = comment.getUsers();
                                if (commentWriter != null && !commentWriter.getId().equals(userId)) {
                                        com.feelscore.back.dto.NotificationEventDto eventDto = com.feelscore.back.dto.NotificationEventDto
                                                        .builder()
                                                        .recipientId(commentWriter.getId())
                                                        .senderId(userId)
                                                        .type(com.feelscore.back.entity.NotificationType.COMMENT_REACTION)
                                                        .relatedId(comment.getPost().getId()) // Use post.getId()
                                                        .title("새로운 반응이 있습니다!")
                                                        .body(user.getNickname() + "님이 회원님의 댓글에 공감했습니다") // Simplified
                                                                                                         // body
                                                        .reactionType(emotionType.toString())
                                                        .relatedContentImageUrl(comment.getPost().getImageUrl())
                                                        .build();

                                        notificationProducer.sendNotification(eventDto);
                                }
                        } catch (Exception e) {
                                System.err.println("Failed to send comment reaction notification: " + e.getMessage());
                                e.printStackTrace();
                        }
                }
        }

        @Transactional
        public void deleteAllCommentsByUser(Long userId) {
                Users user = userRepository.findById(userId).orElseThrow();
                List<Comment> comments = commentRepository.findAllByUsers(user);

                for (Comment comment : comments) {
                        // 댓글에 달린 리액션 삭제
                        commentReactionRepository.deleteAllByComment(comment);
                        // 댓글 삭제
                        commentRepository.delete(comment);
                }
        }

        @Transactional
        public void deleteAllCommentReactionsByUser(Long userId) {
                Users user = userRepository.findById(userId).orElseThrow();
                commentReactionRepository.deleteByUsers(user);
        }

        @Transactional
        public void deleteAllCommentsByPost(Post post) {
                List<Comment> comments = commentRepository.findByPostOrderByCreatedAtAsc(post);
                for (Comment comment : comments) {
                        // 댓글에 달린 리액션 삭제
                        commentReactionRepository.deleteAllByComment(comment);
                        // 댓글 삭제
                        commentRepository.delete(comment);
                }
        }
}
