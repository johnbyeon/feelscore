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
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

/**
 * @brief 매 요청마다 JWT를 검사하여 SecurityContext에 인증 정보를 넣어주는 필터.
 *        - 유효한 JWT 토큰일 경우 CustomUserDetailsService를 통해 UserDetails(CustomUserDetails)를 로드하여
 *          SecurityContext에 인증 정보를 설정합니다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class JwtFilter extends OncePerRequestFilter {

    private final JwtTokenService jwtTokenService;
    private final CustomUserDetailsService customUserDetailsService; // CustomUserDetailsService 주입 추가

    // JWT 검사 예외(화이트리스트) 경로
    private static final List<String> WHITE_LIST = List.of(
            "/api/auth/join",
            "/api/auth/login",
            "/api/auth/refresh",
            "/error",
            "/oauth2/", // OAuth2 관련 경로는 필터에서도 건너뛰도록 추가
            "/login/oauth2/"
    );

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getServletPath();
        return WHITE_LIST.stream().anyMatch(path::startsWith);
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {

        String authHeader = request.getHeader(HttpHeaders.AUTHORIZATION);

        // 1) 토큰이 없거나 "Bearer "로 시작하지 않으면 다음 필터로
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            filterChain.doFilter(request, response);
            return;
        }

        String token = authHeader.substring(7); // "Bearer " 이후 토큰 추출

        // 2) 만료 혹은 잘못된 토큰이면 그냥 통과 (컨트롤러에서 401 처리 가능)
        if (jwtTokenService.isExpired(token)) {
            log.warn("만료되었거나 유효하지 않은 JWT 토큰입니다. (token: {})", token);
            filterChain.doFilter(request, response);
            return;
        }

        // 3) 토큰에서 이메일 추출 및 SecurityContext에 인증 정보가 없는 경우에만 처리
        String email = jwtTokenService.extractEmail(token);

        if (email != null && SecurityContextHolder.getContext().getAuthentication() == null) {
            // CustomUserDetailsService를 통해 UserDetails(CustomUserDetails) 로드
            UserDetails userDetails = customUserDetailsService.loadUserByUsername(email);

            // 로드된 UserDetails를 사용하여 Authentication 객체 생성
            UsernamePasswordAuthenticationToken authentication =
                    new UsernamePasswordAuthenticationToken(
                            userDetails,    // principal을 CustomUserDetails로 설정
                            null,           // credentials (JWT에서는 필요 없음)
                            userDetails.getAuthorities() // CustomUserDetails에서 가져온 권한 사용
                    );

            // SecurityContextHolder에 Authentication 객체 설정
            SecurityContextHolder.getContext().setAuthentication(authentication);
            log.debug("JWT 인증 성공: email={}, roles={}", email, userDetails.getAuthorities());
        }

        // 4) 다음 필터로
        filterChain.doFilter(request, response);
    }
}
