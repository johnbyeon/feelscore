package com.feelscore.back.service;

import com.feelscore.back.dto.JoinRequest;
import com.feelscore.back.entity.Role;
import com.feelscore.back.entity.Users;
import com.feelscore.back.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder encoder;

    public void register(JoinRequest req) {

        if (userRepository.existsByEmail(req.getEmail())) {
            throw new IllegalArgumentException("이미 가입된 이메일입니다.");
        }

        Users user = Users.builder()
                .email(req.getEmail())
                .password(encoder.encode(req.getPassword()))
                .nickname(req.getNickname())   // ✅ DTO랑 엔티티 둘 다 nickname
                .role(Role.USER)               // ✅ 기본 USER 권한
                .build();

        userRepository.save(user);
    }
}
