package com.feelscore.back.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "users")
public class Users extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "user_id")
    private Long id;

    @Column(nullable = false)
    private String nickname;

    private String email; // 소셜 ID 구분용

    @Enumerated(EnumType.STRING)
    private Role role; // USER, ADMIN

    private LocalDateTime lastLoginAt; // 마지막 접속일 (별도 관리)


    // 로그인 시 업데이트 메서드
    public void updateLastLogin() {
        this.lastLoginAt = LocalDateTime.now();
    }
}
