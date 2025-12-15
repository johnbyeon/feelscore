package com.feelscore.back.service;

import com.feelscore.back.dto.ReactionDto;
import com.feelscore.back.dto.ReactionDto;
import com.feelscore.back.entity.EmotionType;
import com.feelscore.back.entity.Post;
import com.feelscore.back.entity.PostReaction;
import com.feelscore.back.entity.Users;
import com.feelscore.back.repository.PostReactionRepository;
import com.feelscore.back.repository.PostRepository;
import com.feelscore.back.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ReactionService {

    private final PostReactionRepository postReactionRepository;
    private final PostRepository postRepository;
    private final UserRepository userRepository;
    private final CategoryStatsService categoryStatsService; // Added dependency
    private final NotificationProducer notificationProducer; // 🔹 알림 발송자 주입

    /**
     * 토글 리액션: 이미 같은 감정이면 삭제, 다른 감정이면 수정, 없으면 생성
     * User can toggle ON/OFF a specific emotion.
     * OR User can switch emotion.
     * Logic:
     * If user clicks 'Joy':
     * - If already reacting 'Joy' -> Remove (Toggle OFF)
     * - If reacting 'Sadness' -> Update to 'Joy' (Switch)
     * - If no reaction -> Create 'Joy' (Toggle ON)
     */
    @Transactional
    public void toggleReaction(Long postId, Long userId, EmotionType emotionType) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new NoSuchElementException("Post not found id: " + postId));
        Users user = userRepository.findById(userId)
                .orElseThrow(() -> new NoSuchElementException("User not found id: " + userId));

        Optional<PostReaction> existingReaction = postReactionRepository.findByPostAndUsers(post, user);

        if (existingReaction.isPresent()) {
            PostReaction reaction = existingReaction.get();
            if (reaction.getEmotionType() == emotionType) {
                // Remove if same emotion (Toggle OFF)
                postReactionRepository.delete(reaction);
                // Update Stats: Subtract
                categoryStatsService.updateUserReactionStats(post.getCategory(), emotionType, false);
            } else {
                // Update if different emotion (Switch)
                EmotionType oldEmotion = reaction.getEmotionType();
                reaction.updateEmotion(emotionType);
                // Update Stats: Subtract Old, Add New
                categoryStatsService.updateUserReactionStats(post.getCategory(), oldEmotion, false);
                categoryStatsService.updateUserReactionStats(post.getCategory(), emotionType, true);
            }
        } else {
            // Create new
            PostReaction newReaction = PostReaction.builder()
                    .post(post)
                    .users(user)
                    .emotionType(emotionType)
                    .build();
            postReactionRepository.save(newReaction);
            // Update Stats: Add
            categoryStatsService.updateUserReactionStats(post.getCategory(), emotionType, true);

            // 🔹 알림 발송 (내 글에 내가 반응하면 알림 X)
            // 🔹 알림 발송 (내 글에 내가 반응하면 알림 X)
            Users postWriter = post.getUsers();
            if (!postWriter.getId().equals(userId)) {
                com.feelscore.back.dto.NotificationEventDto eventDto = com.feelscore.back.dto.NotificationEventDto
                        .builder()
                        .recipientId(postWriter.getId())
                        .senderId(userId)
                        .type(com.feelscore.back.entity.NotificationType.POST_REACTION)
                        .relatedId(postId)
                        .title("새로운 반응이 있습니다!")
                        .body(user.getNickname() + "님이 회원님의 게시글에 공감했습니다") // Body text simplified as icon will show
                                                                          // emotion
                        .reactionType(emotionType.toString())
                        .relatedContentImageUrl(post.getImageUrl())
                        .build();

                notificationProducer.sendNotification(eventDto);
            }
        }
    }

    public ReactionDto.Stats getReactionStats(Long postId, Long userId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new NoSuchElementException("Post not found id: " + postId));

        // Get counts
        List<Object[]> results = postReactionRepository.countReactionsByPost(post);
        Map<EmotionType, Long> counts = new HashMap<>();
        for (Object[] result : results) {
            counts.put((EmotionType) result[0], (Long) result[1]);
        }

        // Fill 0 for missing emotions if needed? Optional, frontend can handle.
        // But for completeness let's ensure map has keys if feasible,
        // or cleaner to just return what we have. Frontend can treat missing as 0.

        // Get my reaction
        EmotionType myReaction = null;
        if (userId != null) {
            Users user = userRepository.findById(userId).orElse(null);
            if (user != null) {
                Optional<PostReaction> reaction = postReactionRepository.findByPostAndUsers(post, user);
                if (reaction.isPresent()) {
                    myReaction = reaction.get().getEmotionType();
                }
            }
        }

        return ReactionDto.Stats.builder()
                .reactionCounts(counts)
                .myReaction(myReaction)
                .build();
    }

    @Transactional
    public void deleteAllPostReactionsByUser(Long userId) {
        Users user = userRepository.findById(userId).orElseThrow();
        postReactionRepository.deleteByUsers(user);
    }
}
