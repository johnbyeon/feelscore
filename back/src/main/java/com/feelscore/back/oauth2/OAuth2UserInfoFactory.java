package com.feelscore.back.oauth2;

import java.util.Map;

public class OAuth2UserInfoFactory {

    public static OAuth2UserInfo getOAuth2UserInfo(String registrationId,
                                                   Map<String, Object> attributes) {
        if (registrationId == null) {
            throw new IllegalArgumentException("registrationId 가 null 입니다.");
        }

        return switch (registrationId.toLowerCase()) {
            case "google" -> new GoogleOAuth2UserInfo(attributes);
            case "kakao" -> new KakaoOAuth2UserInfo(attributes);
            case "naver" -> new NaverOAuth2UserInfo(attributes);
            default -> throw new IllegalArgumentException(
                    "지원하지 않는 OAuth2 제공자: " + registrationId
            );
        };
    }
}
