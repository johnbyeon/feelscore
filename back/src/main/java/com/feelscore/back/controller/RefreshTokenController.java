package com.feelscore.back.controller;

import com.feelscore.back.entity.Users;
import com.feelscore.back.myjwt.JwtTokenService;
import com.feelscore.back.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class RefreshTokenController {

    private final JwtTokenService jwtTokenService;
    private final UserRepository userRepository;

    @PostMapping(value = "/refresh", consumes = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, String> refresh(@RequestBody Map<String, String> body) {

        String refresh = body.get("refresh_token");
        if (refresh == null || refresh.isBlank()) {
            // 토큰이 아예 없을 때
            throw new IllegalArgumentException("refresh_token 이 필요합니다.");
        }

        // 1) 리프레시 토큰 만료 검사
        if (jwtTokenService.isExpired(refresh)) {
            // 여기서는 간단히 예외만 던짐 (전역 예외 처리에서 401로 매핑해도 되고)
            throw new IllegalStateException("만료된 리프레시 토큰입니다.");
        }

        // 2) 리프레시 토큰에서 이메일 추출
        String email = jwtTokenService.extractEmail(refresh);

        // 3) DB에서 유저 조회 후 role 가져오기
        Users user = userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalStateException("사용자를 찾을 수 없습니다."));

        String role = user.getRole().name();  // "USER" / "ADMIN"

        // 4) 새로운 access token 발급
        String newAccessToken = jwtTokenService.createAccessToken(email, role);

        // 5) 새 access token 반환
        return Map.of(
                "access_token", newAccessToken,
                "token_type", "Bearer",
                "email", email,
                "role", role
        );
    }
}
