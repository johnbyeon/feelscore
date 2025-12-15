package com.feelscore.back.service;

import com.feelscore.back.entity.*;
import com.feelscore.back.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
@RequiredArgsConstructor
@Transactional
@Slf4j
public class MentionService {

    private final MentionRepository mentionRepository;
    private final UserRepository userRepository;
    private final FollowRepository followRepository;
    private final NotificationService notificationService;
    private final PostRepository postRepository;

    // @닉네임 패턴 (한글, 영문, 숫자, 언더스코어 허용)
    private static final Pattern MENTION_PATTERN = Pattern.compile("@([\\w가-힣]+)");

    /**
     * 텍스트에서 @닉네임 추출
     */
    public Set<String> parseMentions(String content) {
        Set<String> nicknames = new HashSet<>();
        if (content == null || content.isEmpty()) {
            return nicknames;
        }

        Matcher matcher = MENTION_PATTERN.matcher(content);
        while (matcher.find()) {
            nicknames.add(matcher.group(1));
        }
        return nicknames;
    }

    /**
     * 게시글에서 멘션 처리 (맞팔 유저만)
     */
    public void processMentionsForPost(Post post, Users author, String content) {
        Set<String> mentionedNicknames = parseMentions(content);
        if (mentionedNicknames.isEmpty()) {
            return;
        }

        log.info("Processing mentions for post {}: {}", post.getId(), mentionedNicknames);

        for (String nickname : mentionedNicknames) {
            userRepository.findByNickname(nickname).ifPresent(mentionedUser -> {
                // 본인은 태그 불가
                if (mentionedUser.getId().equals(author.getId())) {
                    return;
                }

                // 맞팔 체크
                if (isMutualFollow(author, mentionedUser)) {
                    // 멘션 저장
                    Mention mention = Mention.createForPost(mentionedUser, author, post);
                    mentionRepository.save(mention);

                    // 알림 전송
                    String message = String.format("%s님이 게시글에서 회원님을 언급했습니다.", author.getNickname());
                    notificationService.sendNotification(
                            author,
                            mentionedUser,
                            NotificationType.MENTION,
                            message,
                            post.getId());

                    log.info("Mention saved: {} mentioned {} in post {}",
                            author.getNickname(), mentionedUser.getNickname(), post.getId());
                } else {
                    log.info("Mention skipped (not mutual follow): {} -> {}",
                            author.getNickname(), mentionedUser.getNickname());
                }
            });
        }
    }

    /**
     * 댓글에서 멘션 처리 (맞팔 유저만)
     */
    public void processMentionsForComment(Comment comment, Users author, String content) {
        Set<String> mentionedNicknames = parseMentions(content);
        if (mentionedNicknames.isEmpty()) {
            return;
        }

        log.info("Processing mentions for comment {}: {}", comment.getId(), mentionedNicknames);

        for (String nickname : mentionedNicknames) {
            userRepository.findByNickname(nickname).ifPresent(mentionedUser -> {
                // 본인은 태그 불가
                if (mentionedUser.getId().equals(author.getId())) {
                    return;
                }

                // 맞팔 체크
                if (isMutualFollow(author, mentionedUser)) {
                    // 멘션 저장
                    Mention mention = Mention.createForComment(mentionedUser, author, comment);
                    mentionRepository.save(mention);

                    // 알림 전송
                    String message = String.format("%s님이 댓글에서 회원님을 언급했습니다.", author.getNickname());
                    notificationService.sendNotification(
                            author,
                            mentionedUser,
                            NotificationType.MENTION,
                            message,
                            comment.getPost().getId());

                    log.info("Mention saved: {} mentioned {} in comment {}",
                            author.getNickname(), mentionedUser.getNickname(), comment.getId());
                }
            });
        }
    }

    /**
     * 맞팔 여부 체크
     */
    private boolean isMutualFollow(Users user1, Users user2) {
        boolean user1FollowsUser2 = followRepository.existsByFollowerAndFollowing(user1, user2);
        boolean user2FollowsUser1 = followRepository.existsByFollowerAndFollowing(user2, user1);
        return user1FollowsUser2 && user2FollowsUser1;
    }

    /**
     * 유저가 태그된 게시글 목록 조회
     */
    @Transactional(readOnly = true)
    public List<Post> getTaggedPosts(Long userId) {
        List<Long> postIds = mentionRepository.findDistinctPostIdsByMentionedUserId(userId);
        if (postIds.isEmpty()) {
            return new ArrayList<>();
        }
        return postRepository.findAllById(postIds);
    }
}
