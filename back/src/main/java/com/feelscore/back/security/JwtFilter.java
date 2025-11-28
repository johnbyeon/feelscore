package com.feelscore.back.security;

import com.feelscore.back.myjwt.JwtTokenService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.*;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

/**
 * 매 요청마다 JWT를 검사해서
 * - 유효하면 SecurityContext에 인증 정보(email + 권한) 넣어주는 필터
 *
 * ✅ 특징
 * - WHITE_LIST 경로는 필터 건너뜀
 * - Authorization: Bearer XXX 에서 토큰 추출
 * - JwtTokenService.isExpired / extractEmail / extractRole 사용
 * - role은 "USER" / "ADMIN" 그대로 authority로 사용 (ROLE_ 안 붙임)
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class JwtFilter extends OncePerRequestFilter {

    private final JwtTokenService jwtTokenService;

    // JWT 검사 예외(화이트리스트) 경로
    private static final List<String> WHITE_LIST = List.of(
            "/api/auth/join",
            "/api/auth/login",
            "/api/auth/refresh",
            "/error"
    );

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getServletPath();
        // 시작 경로 기준으로 간단히 체크
        return WHITE_LIST.stream().anyMatch(path::startsWith);
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {

        String authHeader = request.getHeader(HttpHeaders.AUTHORIZATION);

        // 1) 토큰이 없으면 그냥 다음 필터로
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            filterChain.doFilter(request, response);
            return;
        }

        String token = authHeader.substring(7); // "Bearer " 이후

        // 2) 만료 혹은 잘못된 토큰이면 그냥 통과 (컨트롤러에서 401 처리 가능)
        if (jwtTokenService.isExpired(token)) {
            log.warn("만료되었거나 유효하지 않은 JWT 토큰입니다.");
            filterChain.doFilter(request, response);
            return;
        }

        // 3) 토큰에서 이메일 / 권한(role) 추출
        String email = jwtTokenService.extractEmail(token);
        String role = jwtTokenService.extractRole(token); // "USER" / "ADMIN"

        if (email != null && role != null &&
                SecurityContextHolder.getContext().getAuthentication() == null) {

            // ROLE_ 없이 그대로 authority 사용
            List<GrantedAuthority> authorities =
                    List.of(new SimpleGrantedAuthority(role)); // ex) "ADMIN"

            UserDetails userDetails = User.builder()
                    .username(email)
                    .password("") // 여기서는 패스워드 사용 안 함
                    .authorities(authorities)
                    .build();

            UsernamePasswordAuthenticationToken authentication =
                    new UsernamePasswordAuthenticationToken(
                            userDetails,
                            null,
                            userDetails.getAuthorities()
                    );

            SecurityContextHolder.getContext().setAuthentication(authentication);
        }

        // 4) 다음 필터로
        filterChain.doFilter(request, response);
    }
}
