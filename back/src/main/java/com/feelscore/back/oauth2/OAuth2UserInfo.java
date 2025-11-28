package com.feelscore.back.oauth2;

import java.util.Map;

public abstract class OAuth2UserInfo {

    protected Map<String, Object> attributes;

    public OAuth2UserInfo(Map<String, Object> attributes) {
        this.attributes = attributes;
    }

    /** 각 공급자별 고유 ID */
    public abstract String getId();

    /** 이메일 (없으면 null 가능) */
    public abstract String getEmail();

    /** 이름/닉네임 (없으면 null 가능) */
    public abstract String getName();

    public Map<String, Object> getAttributes() {
        return attributes;
    }
}
