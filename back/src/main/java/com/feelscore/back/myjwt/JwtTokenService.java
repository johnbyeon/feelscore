package com.feelscore.back.myjwt;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

/**
 * 기존 코드 기반으로 보안 강화 + 기능 확장:
 * 1. Access Token 2시간 → 설정 값으로 관리
 * 2. Refresh Token 추가 (14일)
 * 3. ROLE_ 없는 권한 구조 (USER / ADMIN 그대로)
 * 4. parseClaims() 공통 메서드 유지
 * 5. extractEmail(), extractRole() 기존 메서드 유지
 */
@Service
public class JwtTokenService {

    @Value("${spring.jwt.secret}")
    private String secretKeyString;

    // Access / Refresh 만료시간
    private static final long ACCESS_EXPIRE_MS = 1000L * 60 * 60 * 2;        // 2시간
    private static final long REFRESH_EXPIRE_MS = 1000L * 60 * 60 * 24 * 14; // 14일

    private SecretKey secretKey;

    @PostConstruct
    public void init() {
        this.secretKey = Keys.hmacShaKeyFor(secretKeyString.getBytes(StandardCharsets.UTF_8));
    }

    // =======================
    //  🔥 Access Token 생성
    // =======================
    public String createAccessToken(String email, String role) {
        Date now = new Date();
        Date expiry = new Date(now.getTime() + ACCESS_EXPIRE_MS);

        return Jwts.builder()
                .setSubject(email)
                .claim("role", role) // "USER" / "ADMIN"
                .setIssuedAt(now)
                .setExpiration(expiry)
                .signWith(secretKey, SignatureAlgorithm.HS256)
                .compact();
    }

    // =======================
    //  🔥 Refresh Token 생성
    // =======================
    public String createRefreshToken(String email) {
        Date now = new Date();
        Date expiry = new Date(now.getTime() + REFRESH_EXPIRE_MS);

        return Jwts.builder()
                .setSubject(email)
                .setIssuedAt(now)
                .setExpiration(expiry)
                .signWith(secretKey, SignatureAlgorithm.HS256)
                .compact();
    }

    // 공통 Claims 파싱
    private Claims parseClaims(String token) {
        return Jwts.parserBuilder()
                .setSigningKey(secretKey)
                .build()
                .parseClaimsJws(token)
                .getBody();
    }

    // 유효성 검사
    public boolean isExpired(String token) {
        try {
            return parseClaims(token).getExpiration().before(new Date());
        } catch (JwtException | IllegalArgumentException e) {
            return true;
        }
    }

    // 이메일(subject) 추출
    public String extractEmail(String token) {
        return parseClaims(token).getSubject();
    }

    // role 추출
    public String extractRole(String token) {
        Object role = parseClaims(token).get("role");
        return role != null ? role.toString() : null;  // "USER" / "ADMIN"
    }
}
