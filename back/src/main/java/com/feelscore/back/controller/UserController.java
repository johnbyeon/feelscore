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

@RestController
@RequestMapping("/api/user")
@RequiredArgsConstructor
public class UserController {

    private final UserRepository userRepository;

    /**
     * 내 정보 조회 (JWT 필요)
     *
     * GET  /api/user/me
     * POST /api/user/me
     *
     * Header: Authorization: Bearer {accessToken}
     */
    @RequestMapping(value = "/me", method = {RequestMethod.GET, RequestMethod.POST})
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
    public ResponseEntity<String> updateFcmToken(@RequestBody FcmTokenRequest request, Authentication authentication) {
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
}
