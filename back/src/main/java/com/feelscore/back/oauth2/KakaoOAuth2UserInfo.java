package com.feelscore.back.oauth2;

import java.util.Map;

public class KakaoOAuth2UserInfo extends OAuth2UserInfo {

    public KakaoOAuth2UserInfo(Map<String, Object> attributes) {
        super(attributes);
    }

    @Override
    public String getId() {
        Object id = attributes.get("id");
        return id == null ? null : id.toString();
    }

    @Override
    @SuppressWarnings("unchecked")
    public String getEmail() {
        Object accountObj = attributes.get("kakao_account");
        if (!(accountObj instanceof Map<?, ?> account)) {
            return null;
        }
        Object email = account.get("email");
        return email == null ? null : email.toString();
    }

    @Override
    @SuppressWarnings("unchecked")
    public String getName() {
        Object accountObj = attributes.get("kakao_account");
        if (!(accountObj instanceof Map<?, ?> account)) {
            return null;
        }
        Object profileObj = account.get("profile");
        if (!(profileObj instanceof Map<?, ?> profile)) {
            return null;
        }
        Object nickname = profile.get("nickname");
        return nickname == null ? null : nickname.toString();
    }
}
