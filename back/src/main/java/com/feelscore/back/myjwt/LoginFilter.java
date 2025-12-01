package com.feelscore.back.myjwt;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.feelscore.back.entity.Users;
import com.feelscore.back.repository.UserRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.*;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.util.StringUtils;

import java.io.IOException;
import java.io.PrintWriter;
import java.util.*;

/**
 * /api/auth/login 처리용 커스텀 필터
 * - JSON & form 로그인 모두 지원
 * - 로그인 성공 시 Access / Refresh 토큰 발급
 */
@Slf4j
public class LoginFilter extends UsernamePasswordAuthenticationFilter {

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final JwtTokenService jwtTokenService;
    private final UserRepository userRepository;

    public LoginFilter(AuthenticationManager authenticationManager,
                       JwtTokenService jwtTokenService,
                       UserRepository userRepository) {
        this.jwtTokenService = Objects.requireNonNull(jwtTokenService);
        this.userRepository = Objects.requireNonNull(userRepository);
        // 부모 필터에 AuthenticationManager 주입
        super.setAuthenticationManager(Objects.requireNonNull(authenticationManager));
        // 실제 로그인 URL
        super.setFilterProcessesUrl("/api/auth/login");
    }

    /**
     * JSON 또는 x-www-form-urlencoded 둘 다 지원
     * JSON: { "email": "...", "password": "..." }
     */
    @Override
    public Authentication attemptAuthentication(HttpServletRequest request,
                                                HttpServletResponse response)
            throws AuthenticationException {

        log.info("🟢 [LoginFilter] attemptAuthentication() 진입");
        log.info("🟢 요청 URL: {}", request.getRequestURI());
        log.info("🟢 Content-Type: {}", request.getContentType());
        log.info("🟢 메서드: {}", request.getMethod());

        try {
            String contentType = request.getContentType();
            String email;
            String password;

            // 1) JSON 요청이면 body 파싱
            if (contentType != null && contentType.toLowerCase().contains("application/json")) {
                LoginRequest body = objectMapper.readValue(request.getInputStream(), LoginRequest.class);
                email = body.email == null ? "" : body.email.trim();
                password = body.password == null ? "" : body.password;
            } else {
                // 2) form 요청이면 파라미터에서 읽기
                email = StringUtils.hasText(request.getParameter("email")) ? request.getParameter("email") : "";
                password = StringUtils.hasText(request.getParameter("password")) ? request.getParameter("password") : "";
            }

            if (!StringUtils.hasText(email) || !StringUtils.hasText(password)) {
                throw new BadCredentialsException("이메일/비밀번호를 확인해주세요.");
            }

            UsernamePasswordAuthenticationToken authRequest =
                    new UsernamePasswordAuthenticationToken(email, password);

            setDetails(request, authRequest);
            return this.getAuthenticationManager().authenticate(authRequest);

        } catch (IOException e) {
            throw new RuntimeException("로그인 요청 파싱 중 오류가 발생했습니다.", e);
        }
    }

    @Override
    protected void successfulAuthentication(HttpServletRequest request,
                                            HttpServletResponse response,
                                            FilterChain chain,
                                            Authentication authResult) throws IOException {
        log.info("🟢 [LoginFilter] successfulAuthentication() 진입");
        log.info("🟢 인증 성공: {}", authResult.getName());

        String email = authResult.getName();

        // 권한 문자열 하나 꺼내기 (이제 "USER" / "ADMIN" 그대로 들어있다고 가정)
        String role = authResult.getAuthorities().stream()
                .findFirst()
                .map(GrantedAuthority::getAuthority)
                .orElse("USER");
        log.info("🟢 successfulAuthentication role: {}", role);

        // 🔐 JWT 생성 (Access / Refresh)
        String accessToken = jwtTokenService.createAccessToken(email, role);
        String refreshToken = jwtTokenService.createRefreshToken(email);

        // 마지막 로그인 시각 업데이트 (있다면)
        userRepository.findByEmail(email).ifPresent(Users::updateLastLogin);

        // 응답 JSON 만들기
        Map<String, Object> payload = new HashMap<>();
        payload.put("access_token", accessToken);
        payload.put("refresh_token", refreshToken);
        payload.put("token_type", "Bearer");
        payload.put("email", email);
        payload.put("role", role);

        String jsonResponse = objectMapper.writeValueAsString(payload);
        log.info("🟩 [LoginFilter] 최종 응답 JSON = {}", jsonResponse);

        // 응답 설정
        response.setStatus(HttpServletResponse.SC_OK);
        response.setHeader("Authorization", "Bearer " + accessToken);
        response.setContentType("application/json;charset=UTF-8");

        try (PrintWriter out = response.getWriter()) {
            out.write(jsonResponse);
            out.flush();
        }
    }

    @Override
    protected void unsuccessfulAuthentication(HttpServletRequest request,
                                              HttpServletResponse response,
                                              AuthenticationException failed)
            throws IOException {
        log.info("🔴 [LoginFilter] unsuccessfulAuthentication: {}", failed.getMessage());

        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType("application/json;charset=UTF-8");

        Map<String, Object> err = Map.of(
                "error", "invalid_grant",
                "error_description", "아이디 또는 비밀번호가 올바르지 않습니다."
        );

        try (PrintWriter out = response.getWriter()) {
            out.print(objectMapper.writeValueAsString(err));
        }
    }

    /** JSON 바디 파싱용 DTO */
    public static final class LoginRequest {
        public String email;
        public String password;
        public LoginRequest() {}
    }
}
