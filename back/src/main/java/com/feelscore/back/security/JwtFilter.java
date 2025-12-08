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
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

/**
 * 매 요청마다 JWT를 검사해서 SecurityContext에 인증 정보를 넣어주는 필터
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class JwtFilter extends OncePerRequestFilter {

    private final JwtTokenService jwtTokenService;
    private final CustomUserDetailsService customUserDetailsService;

    // JWT 검사 안 하는(화이트리스트) 경로
    private static final List<String> WHITE_LIST = List.of(
            "/api/auth/join",
            "/api/auth/login",
            "/api/auth/refresh",
            "/error",
            "/oauth2/",
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

        String path = request.getServletPath();
        String authHeader = request.getHeader(HttpHeaders.AUTHORIZATION);

        log.debug("[JwtFilter] path={}, authHeader={}", path, authHeader);

        // 1) 토큰이 없거나 "Bearer " 로 시작하지 않으면 그냥 다음 필터로
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            filterChain.doFilter(request, response);
            return;
        }

        String token = authHeader.substring(7); // "Bearer " 이후 부분이 실제 토큰

        try {
            // 2) 만료된 토큰이면 패스
            if (jwtTokenService.isExpired(token)) {
                log.warn("[JwtFilter] 만료된 JWT 토큰입니다. token={}", token);
                filterChain.doFilter(request, response);
                return;
            }

            // 3) 토큰에서 이메일 꺼내기 (로그인/리프레시랑 같은 메서드 사용!)
            String email = jwtTokenService.extractEmail(token);

            // 이미 인증된 상태가 아니고, email 이 있으면 인증 객체 세팅
            if (email != null && SecurityContextHolder.getContext().getAuthentication() == null) {

                UserDetails userDetails = customUserDetailsService.loadUserByUsername(email);

                UsernamePasswordAuthenticationToken authentication =
                        new UsernamePasswordAuthenticationToken(
                                userDetails,
                                null,
                                userDetails.getAuthorities()
                        );

                SecurityContextHolder.getContext().setAuthentication(authentication);
                log.debug("[JwtFilter] JWT 인증 성공: email={}, roles={}",
                        email, userDetails.getAuthorities());
            }

        } catch (Exception e) {
            // JWT 파싱/검증 중 예외 나면 인증 없이 넘기고, 로그만 남김
            log.warn("[JwtFilter] JWT 처리 중 예외 발생: {}", e.getMessage());
            SecurityContextHolder.clearContext();
        }

        // 4) 다음 필터로 넘기기
        filterChain.doFilter(request, response);
    }
}
