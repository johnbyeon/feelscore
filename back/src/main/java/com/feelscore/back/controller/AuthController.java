package com.feelscore.back.controller;

import com.feelscore.back.dto.JoinRequest;
import com.feelscore.back.dto.LoginRequest;
import com.feelscore.back.myjwt.JwtTokenService;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import java.util.HashMap;
import com.feelscore.back.entity.Role;
import com.feelscore.back.entity.Users;
import com.feelscore.back.repository.UserRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

        private final UserRepository userRepository;
        private final PasswordEncoder passwordEncoder;
        private final AuthenticationManager authenticationManager;
        private final JwtTokenService jwtTokenService;

        @PostMapping("/join")
        public ResponseEntity<?> join(@RequestBody @Valid JoinRequest req) {

                // 이미 가입된 이메일인지 체크
                if (userRepository.existsByEmail(req.getEmail())) {
                        return ResponseEntity.status(HttpStatus.CONFLICT)
                                        .body(Map.of("message", "이미 가입된 이메일입니다."));
                }

                // 비밀번호 BCrypt 인코딩해서 저장
                Users user = Users.builder()
                                .email(req.getEmail())
                                .password(passwordEncoder.encode(req.getPassword()))
                                .nickname(req.getNickname())
                                .role(Role.USER) // enum Role { USER, ADMIN }
                                .build();

                userRepository.save(user);

                return ResponseEntity.status(HttpStatus.CREATED)
                                .body(Map.of(
                                                "message", "회원가입이 완료되었습니다.",
                                                "email", user.getEmail(),
                                                "nickname", user.getNickname()));
        }

        @PostMapping("/login")
        public ResponseEntity<?> login(@RequestBody @Valid LoginRequest req) {
                UsernamePasswordAuthenticationToken authenticationToken = new UsernamePasswordAuthenticationToken(
                                req.getEmail(), req.getPassword());

                Authentication authentication = authenticationManager.authenticate(authenticationToken);

                String email = authentication.getName();
                String role = authentication.getAuthorities().stream()
                                .findFirst()
                                .map(GrantedAuthority::getAuthority)
                                .orElse("USER");

                String accessToken = jwtTokenService.createAccessToken(email, role);
                String refreshToken = jwtTokenService.createRefreshToken(email);

                Map<String, Object> payload = new HashMap<>();
                userRepository.findByEmail(email).ifPresent(user -> {
                        user.updateLastLogin();
                        payload.put("id", user.getId());
                        payload.put("nickname", user.getNickname());
                });

                payload.put("access_token", accessToken);
                payload.put("refresh_token", refreshToken);
                payload.put("token_type", "Bearer");
                payload.put("email", email);
                payload.put("role", role);

                return ResponseEntity.ok()
                                .header("Authorization", "Bearer " + accessToken)
                                .body(payload);
        }
}
