package com.feelscore.back.security;

import com.feelscore.back.entity.Users;
import lombok.Getter;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.List;

@Getter
public class CustomUserDetails implements UserDetails {

    private final Users user;

    public CustomUserDetails(Users user) {
        this.user = user;
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {

        String roleName = (user.getRole() != null)
                ? "ROLE_" + user.getRole().name()
                : "ROLE_USER"; // 기본 USER 역할

        return List.of(new SimpleGrantedAuthority(roleName));
    }

    @Override
    public String getPassword() {
        return user.getPassword();
    }

    @Override
    public String getUsername() {
        if (user.getEmail() != null && !user.getEmail().isBlank()) {
            return user.getEmail();
        }
        return user.getNickname(); // 이메일 없을 시 닉네임 사용
    }

    /**
     * @brief 현재 로그인한 유저의 고유 ID (Long 타입) 반환
     *        컨트롤러에서 Authentication.getPrincipal()을 통해 접근 가능
     */
    public Long getUserId() {
        return user.getId(); // Users 엔티티에 getId() 메서드 필요
    }

    @Override
    public boolean isAccountNonExpired() { return true; }

    @Override
    public boolean isAccountNonLocked() { return true; }

    @Override
    public boolean isCredentialsNonExpired() { return true; }

    @Override
    public boolean isEnabled() { return true; }
}
