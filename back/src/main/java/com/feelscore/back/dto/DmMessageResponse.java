package com.feelscore.back.dto;

import com.feelscore.back.entity.DmMessage;
import com.feelscore.back.entity.DmMessageType;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Getter
@NoArgsConstructor
public class DmMessageResponse {
    private Long id;
    private Long threadId;
    private Long senderId;
    private String senderNickname;
    private DmMessageType messageType;
    private String content;
    private String imageUrl;
    private boolean deleted;
    private LocalDateTime createdAt;

    /**
     * 이 메시지가 "내가 보낸 것인지" 여부
     * - 프론트에서 말풍선 위치 결정할 때 사용
     */
    private boolean mine;

    /**
     * 기본 생성자 (mine 정보 없이)
     */
    public DmMessageResponse(DmMessage message) {
        this(message, null);
    }

    /**
     * 현재 로그인 유저 ID를 알고 있을 때 쓰는 생성자
     * 
     * @param message       DM 메시지 엔티티
     * @param currentUserId 현재 로그인한 유저 ID (null이면 mine=false로 처리)
     */
    public DmMessageResponse(DmMessage message, Long currentUserId) {
        this.id = message.getId();
        this.threadId = message.getThread().getId();
        this.senderId = message.getSender().getId();
        this.senderNickname = message.getSender().getNickname();
        this.messageType = message.getMessageType();
        this.content = message.getContent();
        this.imageUrl = message.getImageUrl();
        this.deleted = message.isDeleted();
        this.createdAt = message.getCreatedAt();

        if (currentUserId != null && currentUserId.equals(this.senderId)) {
            this.mine = true;
        } else {
            this.mine = false;
        }
    }
}
