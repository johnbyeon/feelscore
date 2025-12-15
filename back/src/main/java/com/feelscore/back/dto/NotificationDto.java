package com.feelscore.back.dto;

import com.feelscore.back.entity.Notification;
import com.feelscore.back.entity.NotificationType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

public class NotificationDto {

    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class Response {
        private Long id;
        private NotificationType type;
        private String content;
        private Long relatedId;
        private boolean isRead;
        private LocalDateTime createdAt;
        private String reactionType;
        private String relatedContentImageUrl;

        // Sender info
        private Long senderId;
        private String senderNickname;
        private String senderProfileImage;

        public static Response from(Notification notification) {
            ResponseBuilder builder = Response.builder()
                    .id(notification.getId())
                    .type(notification.getType())
                    .content(notification.getContent())
                    .relatedId(notification.getRelatedId())
                    .isRead(notification.isRead())
                    .createdAt(notification.getCreatedAt())
                    .reactionType(notification.getReactionType())
                    .relatedContentImageUrl(notification.getRelatedContentImageUrl());

            if (notification.getSender() != null) {
                builder.senderId(notification.getSender().getId())
                        .senderNickname(notification.getSender().getNickname())
                        .senderProfileImage(notification.getSender().getProfileImageUrl());
            }

            return builder.build();
        }
    }
}
