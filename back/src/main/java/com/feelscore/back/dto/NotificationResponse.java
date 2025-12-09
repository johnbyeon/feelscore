package com.feelscore.back.dto;

import com.feelscore.back.entity.Notification;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 알림 응답 DTO
 * - Notification 엔티티를 직접 반환하면 Users 정보(비밀번호 등)가 노출될 수 있어,
 * 보안상 안전한 필드만 추려서 반환하기 위함.
 */
@Getter
@NoArgsConstructor
public class NotificationResponse {

    private Long id;
    private String type;
    private String message;
    private String relatedUrl;
    private boolean read;
    private LocalDateTime createdAt;

    public NotificationResponse(Notification notification) {
        this.id = notification.getId();
        this.type = notification.getType();
        this.message = notification.getMessage();
        this.relatedUrl = notification.getRelatedUrl();
        this.read = notification.isRead();
        this.createdAt = notification.getCreatedAt();
    }
}
