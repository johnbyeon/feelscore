package com.feelscore.back.oauth2;

import java.util.Map;

@SuppressWarnings("unchecked")
public class NaverOAuth2UserInfo extends OAuth2UserInfo {

    public NaverOAuth2UserInfo(Map<String, Object> attributes) {
        // 네이버는 response 안에 유저 정보가 들어 있음
        super((Map<String, Object>) attributes.get("response"));
    }

    @Override
    public String getId() {
        Object id = attributes.get("id");
        return id == null ? null : id.toString();
    }

    @Override
    public String getEmail() {
        Object email = attributes.get("email");
        return email == null ? null : email.toString();
    }

    @Override
    public String getName() {
        Object name = attributes.get("name");
        return name == null ? null : name.toString();
    }
}
