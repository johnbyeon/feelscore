package com.feelscore.back.oauth2;

import com.feelscore.back.entity.Role;
import com.feelscore.back.entity.Users;
import com.feelscore.back.myjwt.JwtTokenService;
import com.feelscore.back.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.client.authentication.OAuth2AuthenticationToken;
import org.springframework.security.oauth2.core.user.OAuth2User;
import org.springframework.security.web.authentication.AuthenticationSuccessHandler;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.Optional;

@Slf4j
@Component
@RequiredArgsConstructor
public class OAuth2SuccessHandler implements AuthenticationSuccessHandler {

    private final JwtTokenService jwtTokenService;
    private final UserRepository userRepository;

    // LoginFilter랑 맞춰서: AccessToken만 발급 (2시간 가정)
    private static final long ACCESS_TOKEN_EXPIRE_SEC = 60L * 60 * 2;   // 2시간

    @Override
    public void onAuthenticationSuccess(HttpServletRequest request,
                                        HttpServletResponse response,
                                        Authentication authentication) throws IOException {

        try {
            // 1) Spring이 만들어준 OAuth2 토큰 정보 꺼내기
            OAuth2AuthenticationToken oauthToken = (OAuth2AuthenticationToken) authentication;
            String registrationId = oauthToken.getAuthorizedClientRegistrationId(); // google / kakao / naver
            OAuth2User oAuth2User = (OAuth2User) oauthToken.getPrincipal();

            // 2) 우리 공통 파서로 이메일/이름 뽑기
            OAuth2UserInfo userInfo =
                    OAuth2UserInfoFactory.getOAuth2UserInfo(registrationId, oAuth2User.getAttributes());

            String email = userInfo.getEmail();
            String name  = userInfo.getName();

            log.info("🔐 OAuth2 SUCCESS raw: provider={}, email={}, name={}",
                    registrationId, email, name);

            if (email == null || email.isBlank()) {
                throw new IllegalStateException("소셜 로그인에서 이메일을 가져오지 못했습니다.");
            }

            // 3) DB에 유저가 있나 확인 → 없으면 간단히 회원 생성
            Users user = findOrCreateUser(email, name);
            String roleName = user.getRole() != null
                    ? "ROLE_" + user.getRole().name()   // ROLE_USER / ROLE_ADMIN
                    : "ROLE_USER";

            // 4) JWT Access Token 생성 (LoginFilter랑 동일한 방식)
            String accessToken = jwtTokenService.createAccessToken(email, roleName);

            // 5) 프론트에 넘길 user JSON (필요시 필드 추가 가능)
            String userJson = """
                    {
                      "email":"%s",
                      "nickname":"%s",
                      "role":"%s"
                    }
                    """.formatted(
                    js(user.getEmail()),
                    js(user.getNickname()),
                    js(user.getRole().name())
            );

            boolean needProfile = false; // 프로필 추가 입력 유도하고 싶으면 조건 넣기

            log.info("🔐 OAuth2 FINAL: email={}, role={}, needProfile={}",
                    email, roleName, needProfile);

            // 6) 팝업 창에서 부모 윈도우(React)로 postMessage 후 창 닫기
            response.setContentType("text/html;charset=UTF-8");
            response.getWriter().write("""
<!doctype html>
<html><body>
<script>
  (function () {
    try {
      const data = {
        access_token: "%s",
        expires_in: %d,
        need_profile: %s,
        user: %s
      };
      if (window.opener) {
        window.opener.postMessage(data, "*");
        console.log('[OAuth2SuccessHandler] postMessage sent', data);
      } else {
        console.warn('[OAuth2SuccessHandler] no opener window');
      }
    } catch (e) {
      console.error('[OAuth2SuccessHandler] postMessage error', e);
    }
    setTimeout(function() {
      try { window.close(); } catch (e) {}
    }, 300);
  })();
</script>
</body></html>
""".formatted(
                    js(accessToken),
                    ACCESS_TOKEN_EXPIRE_SEC,
                    needProfile ? "true" : "false",
                    userJson
            ));

        } catch (Exception e) {
            log.error("OAuth2 success handling failed", e);
            response.sendError(500, "OAuth2 success handling failed: " + e.getMessage());
        }
    }

    /**
     * DB에서 유저 찾고, 없으면 새로 만드는 로직
     */
    private Users findOrCreateUser(String email, String name) {
        Optional<Users> optional = userRepository.findByEmail(email);
        if (optional.isPresent()) {
            return optional.get();
        }

        String nickname = (name != null && !name.isBlank())
                ? name
                : email.split("@")[0];

        Users user = Users.builder()
                .email(email)
                .password("")         // 소셜 로그인이라 비밀번호 사용 안 함
                .nickname(nickname)
                .role(Role.USER)
                .build();

        return userRepository.save(user);
    }

    /**
     * JS 문자열 이스케이프
     */
    private static String js(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
