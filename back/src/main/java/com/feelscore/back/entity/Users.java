package com.feelscore.back.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
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

    @Column(nullable = false, unique = true)
    private String email; // 소셜 ID 구분용

    @Column(nullable = false)
    private String password; // 🔹 비밀번호 추가 (BCrypt 인코딩)

    @Enumerated(EnumType.STRING)
    private Role role; // USER, ADMIN

    private LocalDateTime lastLoginAt; // 마지막 접속일 (별도 관리)

    @Builder
    private Users(String email, String password, String nickname, Role role) {
        this.email = email;
        this.password = password;
        this.nickname = nickname;
        this.role = role == null ? Role.USER : role;
    }

    /**
     * @brief 유저의 마지막 로그인 시간을 업데이트합니다.
     */
    public void updateLastLogin() {
        this.lastLoginAt = LocalDateTime.now();
    }

    /**
     * @brief 유저의 역할을 업데이트합니다.
     *        관리자 패널 등에서 유저의 권한을 변경할 때 사용됩니다.
     * @param newRole 새로 설정할 유저 역할 (ROLE_USER, ROLE_ADMIN 등)
     */
    public void updateRole(Role newRole) {
        this.role = newRole;
    }
}
