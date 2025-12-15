package com.feelscore.back.controller;

import com.feelscore.back.entity.Role;
import com.feelscore.back.entity.Users;
import com.feelscore.back.repository.UserRepository;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;

import java.util.List;
import java.util.stream.Collectors;

import java.util.Map;

@RestController
@RequestMapping("/api/user")
@RequiredArgsConstructor
public class UserController {

        private final UserRepository userRepository;

        /**
         * 내 정보 조회 (JWT 필요)
         *
         * GET /api/user/me
         * POST /api/user/me
         *
         * Header: Authorization: Bearer {accessToken}
         */
        @RequestMapping(value = "/me", method = { RequestMethod.GET, RequestMethod.POST })
        public ResponseEntity<UserMeResponse> getMyInfo(Authentication authentication) {

                // LoginFilter + CustomUserDetails 에서 넣어준 username(email)
                String email = authentication.getName();

                Users user = userRepository.findByEmail(email)
                                .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));

                UserMeResponse response = new UserMeResponse(
                                user.getId(),
                                user.getEmail(),
                                user.getNickname(),
                                user.getRole());

                return new ResponseEntity<>(response, HttpStatus.OK);
        }

        @Getter
        @AllArgsConstructor
        public static class UserMeResponse {
                private Long id;
                private String email;
                private String nickname;
                private Role role;
        }

        /** FCM 토큰 업데이트 */
        @PostMapping("/fcm-token")
        public ResponseEntity<String> updateFcmToken(@RequestBody FcmTokenRequest request,
                        Authentication authentication) {
                String email = authentication.getName();
                Users user = userRepository.findByEmail(email)
                                .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));

                user.updateFcmToken(request.getToken());
                userRepository.save(user); // 변경사항 저장

                return ResponseEntity.ok("FCM Token updated successfully");
        }

        @Getter
        @NoArgsConstructor
        public static class FcmTokenRequest {
                private String token;
        }

        @PatchMapping("/profile-image")
        public ResponseEntity<Void> updateProfileImage(Authentication authentication,
                        @RequestBody Map<String, String> request) {
                String email = authentication.getName();
                String profileImageUrl = request.get("profileImageUrl");

                Users user = userRepository.findByEmail(email)
                                .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));

                user.updateProfileImage(profileImageUrl);
                userRepository.save(user); // JPA Dirty Checking으로 생략 가능하지만 명시적으로 저장

                return ResponseEntity.ok().build();
        }

        private final com.feelscore.back.service.UserService userService;

        /**
         * 회원 탈퇴
         * DELETE /api/user
         */
        /**
         * 회원 탈퇴
         * DELETE /api/user
         */
        @RequestMapping(method = RequestMethod.DELETE)
        public ResponseEntity<?> deleteUser(Authentication authentication) {
                try {
                        String email = authentication.getName();
                        Users user = userRepository.findByEmail(email)
                                        .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));

                        userService.withdraw(user.getId());
                        return ResponseEntity.ok().build();
                } catch (Exception e) {
                        e.printStackTrace();
                        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                                        .body(Map.of(
                                                        "error", e.getClass().getName() + ": " + e.getMessage(),
                                                        "trace",
                                                        e.getStackTrace().length > 0 ? e.getStackTrace()[0].toString()
                                                                        : "No stack trace"));
                }
        }

        @PostMapping("/emotion/today")
        public ResponseEntity<Void> updateTodayEmotion(@RequestBody Map<String, String> request,
                        Authentication authentication) {
                String email = authentication.getName();
                Users user = userRepository.findByEmail(email)
                                .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));
                com.feelscore.back.entity.EmotionType emotion = com.feelscore.back.entity.EmotionType
                                .valueOf(request.get("emotion"));
                userService.updateTodayEmotion(user.getId(), emotion);
                return ResponseEntity.ok().build();
        }

        @org.springframework.web.bind.annotation.GetMapping("/emotion/today")
        public ResponseEntity<Map<String, Object>> getMyTodayEmotion(Authentication authentication) {
                String email = authentication.getName();
                Users user = userRepository.findByEmail(email).orElseThrow();
                return ResponseEntity.ok(userService.getMyTodayEmotion(user.getId()));
        }

        @org.springframework.web.bind.annotation.GetMapping("/emotion/history")
        public ResponseEntity<java.util.List<Map<String, Object>>> getEmotionHistory(
                        Authentication authentication,
                        @org.springframework.web.bind.annotation.RequestParam("startDate") String startDateStr,
                        @org.springframework.web.bind.annotation.RequestParam("endDate") String endDateStr) {
                String email = authentication.getName();
                Users user = userRepository.findByEmail(email)
                                .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));

                java.time.LocalDate startDate = java.time.LocalDate.parse(startDateStr);
                java.time.LocalDate endDate = java.time.LocalDate.parse(endDateStr);

                return ResponseEntity.ok(userService.getEmotionHistory(user.getId(), startDate, endDate));
        }

        @PatchMapping("/profile")
        public ResponseEntity<Void> updateProfile(
                        Authentication authentication,
                        @RequestBody Map<String, String> request) {
                String email = authentication.getName();
                Users user = userRepository.findByEmail(email)
                                .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));

                String nickname = request.get("nickname");
                String currentPassword = request.get("currentPassword");
                String newPassword = request.get("newPassword");

                userService.updateProfile(user.getId(), nickname, currentPassword, newPassword);
                return ResponseEntity.ok().build();
        }

        @org.springframework.web.bind.annotation.GetMapping("/following/status/today")
        public ResponseEntity<java.util.List<java.util.Map<String, Object>>> getFollowersTodayStatus(
                        Authentication authentication) {
                String email = authentication.getName();
                Users user = userRepository.findByEmail(email)
                                .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));
                return ResponseEntity.ok(userService.getFollowersTodayStatus(user.getId()));
        }

        private final com.feelscore.back.service.ActiveUserService activeUserService;

        @org.springframework.web.bind.annotation.GetMapping("/{userId}/status")
        public ResponseEntity<Map<String, Boolean>> getUserStatus(
                        @org.springframework.web.bind.annotation.PathVariable Long userId) {
                boolean isOnline = activeUserService.isUserActive(userId);
                return ResponseEntity.ok(Map.of("isOnline", isOnline));
        }

        /**
         * 사용자 검색 (닉네임 기준)
         * GET /api/user/search?q={query}
         */
        @GetMapping("/search")
        public ResponseEntity<List<UserSearchResponse>> searchUsers(
                        @RequestParam("q") String query,
                        Authentication authentication) {

                String email = authentication.getName();
                Users currentUser = userRepository.findByEmail(email)
                                .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));

                List<Users> users = userRepository.findByNicknameContainingIgnoreCase(query);

                List<UserSearchResponse> response = users.stream()
                                .filter(u -> !u.getId().equals(currentUser.getId())) // 본인 제외
                                .limit(20) // 최대 20명
                                .map(u -> new UserSearchResponse(
                                                u.getId(),
                                                u.getNickname(),
                                                u.getProfileImageUrl()))
                                .collect(Collectors.toList());

                return ResponseEntity.ok(response);
        }

        @Getter
        @AllArgsConstructor
        public static class UserSearchResponse {
                private Long id;
                private String nickname;
                private String profileImageUrl;
        }

        private final com.feelscore.back.service.MentionService mentionService;
        private final com.feelscore.back.service.PostService postService;

        /**
         * 유저가 태그된 게시글 목록 조회
         * GET /api/user/{userId}/tagged-posts
         */
        @GetMapping("/{userId}/tagged-posts")
        public ResponseEntity<List<com.feelscore.back.dto.PostDto.ListResponse>> getTaggedPosts(
                        @org.springframework.web.bind.annotation.PathVariable Long userId,
                        Authentication authentication) {

                String email = authentication.getName();
                Users currentUser = userRepository.findByEmail(email)
                                .orElseThrow(() -> new RuntimeException("사용자를 찾을 수 없습니다."));

                List<com.feelscore.back.entity.Post> posts = mentionService.getTaggedPosts(userId);

                List<com.feelscore.back.dto.PostDto.ListResponse> response = posts.stream()
                                .map(post -> postService.getPostListResponse(post, currentUser.getId()))
                                .collect(Collectors.toList());

                return ResponseEntity.ok(response);
        }
}
