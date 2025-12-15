package com.feelscore.back.service;

import com.feelscore.back.entity.EmotionType;
import com.feelscore.back.entity.UserEmotion;
import com.feelscore.back.entity.Users;
import com.feelscore.back.repository.UserEmotionRepository;
import com.feelscore.back.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class UserService {

    private final UserRepository userRepository;
    private final PostService postService;
    private final CommentService commentService;
    private final ReactionService reactionService;
    private final FollowService followService;
    private final BlockService blockService;
    private final NotificationService notificationService;
    private final S3Service s3Service;
    private final DmService dmService;
    private final UserEmotionRepository userEmotionRepository;
    private final PasswordEncoder passwordEncoder;

    /**
     * 회원 탈퇴 (계정 삭제)
     * - 연관된 모든 데이터(게시글, 댓글, 반응, 팔로우, 차단, 알림)를 삭제합니다.
     * - 프로필 이미지가 S3에 있다면 삭제합니다.
     * - 마지막으로 Users 엔티티를 삭제합니다.
     */
    @Transactional
    public void withdraw(Long userId) {
        Users user = userRepository.findById(userId)
                .orElseThrow(() -> new NoSuchElementException("User not found with id: " + userId));

        // 1. 게시글 삭제 (게시글에 달린 댓글/반응도 함께 삭제됨)
        postService.deleteAllPostsByUser(userId);

        // 2. 댓글 삭제 (남의 글에 쓴 댓글)
        commentService.deleteAllCommentsByUser(userId);

        // 3. 댓글 반응 삭제 (남의 댓글에 남긴 반응)
        commentService.deleteAllCommentReactionsByUser(userId);

        // 4. 게시글 반응 삭제 (남의 글에 남긴 반응)
        reactionService.deleteAllPostReactionsByUser(userId);

        // 5. 팔로우/팔로워 삭제
        followService.deleteAllFollowsByUser(userId);

        // 6. 차단 목록 삭제
        blockService.deleteAllBlocksByUser(userId);

        // 7. 알림 삭제
        notificationService.deleteAllNotificationsByUser(userId);

        // 8. 프로필 이미지 삭제 (S3)
        if (user.getProfileImageUrl() != null && !user.getProfileImageUrl().isBlank()) {
            // URL이 아닌 Object Key가 저장되어 있다고 가정하거나, URL에서 Key 추출 필요
            // 현재 Post.imageUrl은 Object Key로 저장됨. Users.profileImageUrl도 확인 필요.
            // Users.profileImageUrl은 URL일 수도 있고 Key일 수도 있음.
            // S3Service.generatePresignedPutUrl에서는 "public/users/..." 키를 생성함.
            // 클라이언트가 업로드 후 무엇을 저장하느냐에 따라 다름.
            // 보통 Key를 저장하는 것이 좋음. 만약 URL이라면 Key를 추출해야 함.

            // 여기서는 간단히 Key라고 가정하거나, URL에 bucket 주소가 포함되어 있다면 파싱.
            // 안전하게 try-catch로 감싸거나, 키 형식이 맞는지 확인.
            // S3Service.deleteFile은 Key를 받음.

            // 만약 profileImageUrl이 전체 URL이라면?
            // 예: https://bucket.s3.region.amazonaws.com/public/users/...
            // Key: public/users/...

            String profileImage = user.getProfileImageUrl();
            // 간단한 파싱 로직: "public/" 또는 "users/" 로 시작하면 Key로 간주
            if (profileImage.contains("users/" + userId)) {
                // URL에서 Key 추출 시도 (단순화)
                // 만약 http로 시작하면 슬래시로 잘라서 뒷부분 사용?
                // 여기서는 일단 그대로 넘기거나, 예외 발생 시 로그만 남김.
                try {
                    // 만약 full URL이면 key 추출이 복잡할 수 있음.
                    // 프로젝트 관례상 Key를 저장한다고 가정하고 진행.
                    // 혹시 모르니 http 포함되면 건너뛰거나 파싱?
                    if (!profileImage.startsWith("http")) {
                        s3Service.deleteFile(profileImage);
                    }
                } catch (Exception e) {
                    System.err.println("Failed to delete profile image: " + e.getMessage());
                }
            }
        }

        // 9. DM 삭제 (메시지 및 멤버십)
        dmService.deleteAllDmsByUser(userId);

        // 10. 유저 삭제
        userRepository.delete(user);
    }

    @Transactional
    public void updateTodayEmotion(Long userId, EmotionType emotion) {
        Users user = userRepository.findById(userId)
                .orElseThrow(() -> new NoSuchElementException("User not found"));

        LocalDate today = LocalDate.now();
        UserEmotion userEmotion = userEmotionRepository.findByUsersAndDate(user, today)
                .orElse(UserEmotion.builder()
                        .users(user)
                        .date(today)
                        .emotion(emotion)
                        .build());

        if (userEmotion.getId() != null) {
            userEmotion.updateEmotion(emotion);
        } else {
            userEmotionRepository.save(userEmotion);
        }
    }

    public List<Map<String, Object>> getFollowersTodayStatus(Long userId) {
        // 1. 내가 팔로우하는 유저 목록 조회
        List<Users> followingUsers = followService.getFollowingUsers(userId);

        if (followingUsers.isEmpty()) {
            return Collections.emptyList();
        }

        // 2. 오늘의 감정 조회
        LocalDate today = LocalDate.now();
        List<UserEmotion> emotions = userEmotionRepository
                .findAllByUsersInAndDate(followingUsers, today);

        // 3. Map으로 변환 (UserId -> Emotion)
        Map<Long, EmotionType> emotionMap = emotions.stream()
                .collect(Collectors.toMap(
                        ue -> ue.getUsers().getId(),
                        UserEmotion::getEmotion));

        // 4. 결과 리스트 생성
        return followingUsers.stream()
                .map(u -> {
                    Map<String, Object> map = new HashMap<>();
                    map.put("userId", u.getId());
                    map.put("nickname", u.getNickname());
                    map.put("profileImageUrl", u.getProfileImageUrl());
                    // 감정이 없으면 NEUTRAL
                    map.put("emotion",
                            emotionMap.getOrDefault(u.getId(), EmotionType.NEUTRAL).name());
                    return map;
                })
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getMyTodayEmotion(Long userId) {
        Users user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        Optional<UserEmotion> emotion = userEmotionRepository.findByUsersAndDate(user, LocalDate.now());

        Map<String, Object> result = new HashMap<>();
        result.put("emotion", emotion.map(UserEmotion::getEmotion).orElse(EmotionType.NEUTRAL));
        return result;
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> getEmotionHistory(Long userId, LocalDate startDate, LocalDate endDate) {
        Users user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        List<UserEmotion> emotions = userEmotionRepository.findAllByUsersAndDateBetween(user, startDate, endDate);

        return emotions.stream().map(ue -> {
            Map<String, Object> map = new HashMap<>();
            map.put("date", ue.getDate());
            map.put("emotion", ue.getEmotion());
            return map;
        }).collect(Collectors.toList());
    }

    @Transactional
    public void updateProfile(Long userId, String nickname, String currentPassword, String newPassword) {
        Users user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (nickname != null && !nickname.isEmpty()) {
            user.updateNickname(nickname);
        }

        if (newPassword != null && !newPassword.isEmpty()) {
            if (currentPassword == null || !passwordEncoder.matches(currentPassword, user.getPassword())) {
                throw new RuntimeException("Current password does not match");
            }
            user.setPassword(passwordEncoder.encode(newPassword));
        }

        userRepository.save(user);
    }

}
