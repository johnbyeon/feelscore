package com.feelscore.back.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "notifications")
public class Notification extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "notification_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "recipient_id", nullable = false)
    private Users recipient;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sender_id", nullable = false)
    private Users sender;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private NotificationType type;

    @Column(nullable = false)
    private String content;

    @Column(name = "related_id")
    private Long relatedId; // PostId, CommentId, etc.

    @Column(name = "is_read", nullable = false)
    private boolean isRead;

    @Column(name = "reaction_type")
    private String reactionType; // LIKE, LOVE, HAHA, etc.

    @Column(name = "related_content_image_url")
    private String relatedContentImageUrl; // Snapshot of post image

    @Builder
    public Notification(Users recipient, Users sender, NotificationType type, String content, Long relatedId,
            String reactionType, String relatedContentImageUrl) {
        this.recipient = recipient;
        this.sender = sender;
        this.type = type;
        this.content = content;
        this.relatedId = relatedId;
        this.isRead = false;
        this.reactionType = reactionType;
        this.relatedContentImageUrl = relatedContentImageUrl;
    }

    public void markAsRead() {
        this.isRead = true;
    }
}
