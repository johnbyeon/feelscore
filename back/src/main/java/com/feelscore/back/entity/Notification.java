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

    @Builder
    public Notification(Users recipient, Users sender, NotificationType type, String content, Long relatedId) {
        this.recipient = recipient;
        this.sender = sender;
        this.type = type;
        this.content = content;
        this.relatedId = relatedId;
        this.isRead = false;
    }

    public void markAsRead() {
        this.isRead = true;
    }
}
