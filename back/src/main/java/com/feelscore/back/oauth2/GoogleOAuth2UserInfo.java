package com.feelscore.back.oauth2;

import java.util.Map;

public class GoogleOAuth2UserInfo extends OAuth2UserInfo {

    public GoogleOAuth2UserInfo(Map<String, Object> attributes) {
        super(attributes);
    }

    @Override
    public String getId() {
        // Google OIDC에서는 "sub"가 고유 ID
        Object v = attributes.get("sub");
        return v == null ? null : v.toString();
    }

    @Override
    public String getEmail() {
        Object v = attributes.get("email");
        return v == null ? null : v.toString();
    }

    @Override
    public String getName() {
        Object v = attributes.get("name");
        return v == null ? null : v.toString();
    }
}
