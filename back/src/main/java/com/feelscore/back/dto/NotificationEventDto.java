package com.feelscore.back.dto;

import com.feelscore.back.entity.NotificationType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NotificationEventDto {
    private Long recipientId;
    private Long senderId;
    private NotificationType type;
    private Long relatedId; // PostId, CommentId, or UserId (for Follow)
    private String title;
    private String body;
    private String reactionType;
    private String relatedContentImageUrl;
}
