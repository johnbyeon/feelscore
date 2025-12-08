package com.feelscore.back.entity;

public enum DmMemberState {
    NORMAL,   // 정상 DM
    REQUEST,  // 메시지 요청 상태(비팔로우가 보낸 첫 DM)
    BLOCKED,  // 차단
    DELETED   // 내가 삭제한 상태(상대방은 그대로)
}
