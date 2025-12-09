package com.feelscore.back.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

@Entity
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EntityListeners(AuditingEntityListener.class)
@Table(name = "notification")
public class Notification {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private Users user; // 알림 받는 사람

    @Column(nullable = false)
    private String type; // 알림 타입 (예: "DM", "FOLLOW")

    @Column(nullable = false)
    private String message; // 알림 내용

    private String relatedUrl; // 클릭 시 이동할 경로

    @Column(nullable = false)
    private boolean isRead; // 읽음 여부

    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;

    // 읽음 처리 메서드
    public void read() {
        this.isRead = true;
    }

    public static Notification create(Users user, String type, String message, String relatedUrl) {
        return Notification.builder()
                .user(user)
                .type(type)
                .message(message)
                .relatedUrl(relatedUrl)
                .isRead(false)
                .build();
    }
}
