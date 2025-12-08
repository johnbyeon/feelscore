package com.feelscore.back.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
public class DmSendMessageRequest {

    /**
     * 기존 쓰레드에 보낼 때 사용하는 ID (선택)
     * - 있으면 이 thread에 그대로 메시지 전송
     * - 없으면 receiverId 기준으로 쓰레드 생성/조회
     */
    private Long threadId;

    /**
     * 새 DM을 시작할 때 사용하는 상대 유저 ID
     * - threadId가 null이고, receiverId가 있으면
     * senderId + receiverId 조합으로 쓰레드 찾거나 새로 만듦
     */
    private Long receiverId;

    /**
     * 메시지 내용
     */
    private String content;
}
