package com.feelscore.back.config;

import com.feelscore.back.myjwt.JwtTokenService;
import com.feelscore.back.myjwt.LoginFilter;
import com.feelscore.back.oauth2.OAuth2FailureHandler;
import com.feelscore.back.oauth2.OAuth2LoggingFilter;
import com.feelscore.back.oauth2.OAuth2SuccessHandler;
import com.feelscore.back.repository.UserRepository;

import com.feelscore.back.security.CustomUserDetailsService;
import com.feelscore.back.security.JwtFilter;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.authentication.builders.AuthenticationManagerBuilder;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final CustomUserDetailsService customUserDetailsService;
    private final JwtTokenService jwtTokenService;
    private final JwtFilter jwtFilter;           // 우리가 수정한 JwtFilter(@Component)
    private final UserRepository userRepository;
    private final OAuth2SuccessHandler oAuth2SuccessHandler;
    private final OAuth2FailureHandler oAuth2FailureHandler;
    private final OAuth2LoggingFilter oAuth2LoggingFilter;

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    /**
     * DaoAuthenticationProvider + CustomUserDetailsService를 사용하는 AuthenticationManager
     */
    @Bean
    public AuthenticationManager authenticationManager(HttpSecurity http) throws Exception {
        AuthenticationManagerBuilder builder =
                http.getSharedObject(AuthenticationManagerBuilder.class);

        DaoAuthenticationProvider provider = new DaoAuthenticationProvider();
        provider.setUserDetailsService(customUserDetailsService);
        provider.setPasswordEncoder(passwordEncoder());

        builder.authenticationProvider(provider);

        return builder.build();
    }

    /**
     * 전체 Security 필터 체인
     */
    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http,
                                                   AuthenticationManager authManager) throws Exception {

        // 우리가 앞에서 수정한 LoginFilter (Access/Refresh 발급하는 버전)
        LoginFilter loginFilter = new LoginFilter(authManager, jwtTokenService, userRepository);
        loginFilter.setFilterProcessesUrl("/api/auth/login");

        http
                // JWT 기반이니까 CSRF, formLogin, httpBasic 비활성화
                .csrf(csrf -> csrf.disable())
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .formLogin(fl -> fl.disable())
                .httpBasic(hb -> hb.disable())

                // 인증 실패 시 401 JSON 리턴
                .exceptionHandling(eh -> eh.authenticationEntryPoint((req, res, ex) -> {
                    res.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                    res.setContentType("application/json;charset=UTF-8");
                    res.getWriter().write("{\"error\":\"unauthorized\"}");
                }))

                // 요청별 권한 설정
                .authorizeHttpRequests(auth -> auth
                        // 회원가입/로그인, 에러는 모두 허용
                        .requestMatchers(HttpMethod.POST, "/api/auth/join", "/api/auth/login","/api/auth/refresh").permitAll()
                        .requestMatchers("/error").permitAll()

                        // OAuth2 관련 URL은 전부 허용
                        .requestMatchers(
                                "/oauth2/**",
                                "/login/oauth2/**",
                                "/oauth2/authorization/**"
                        ).permitAll()

                        // 필요하면 나중에 이렇게 더 세분화 가능
                        // .requestMatchers("/api/admin/**").hasAuthority("ADMIN")
                        // .requestMatchers("/api/user/**").hasAuthority("USER")

                        .anyRequest().authenticated()
                )

                // ===== OAuth2 소셜 로그인 설정 =====
                .oauth2Login(o -> o
                        // 프론트 /login 과 충돌 안 나게 더미 로그인 페이지 경로
                        .loginPage("/api/auth/oauth2/login")
                        .authorizationEndpoint(a -> a.baseUri("/oauth2/authorization"))
                        .redirectionEndpoint(r -> r.baseUri("/login/oauth2/code/*"))
                        .successHandler(oAuth2SuccessHandler)
                        .failureHandler(oAuth2FailureHandler)
                )

                // ===== 필터 체인 순서 =====
                // OAuth2 콜백 로그 찍는 필터 (선택)
                .addFilterBefore(oAuth2LoggingFilter, UsernamePasswordAuthenticationFilter.class)
                // JWT 인증 필터: 매 요청마다 토큰 검증
                .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)
                // 로그인 처리 필터: /api/auth/login (ID/PW)
                .addFilterAt(loginFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(List.of("*"));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(true);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}



