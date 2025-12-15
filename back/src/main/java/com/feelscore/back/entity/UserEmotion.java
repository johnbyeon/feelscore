package com.feelscore.back.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@EntityListeners(AuditingEntityListener.class)
@Table(name = "user_emotions", uniqueConstraints = {
        @UniqueConstraint(name = "uk_user_date", columnNames = { "user_id", "date" })
})
public class UserEmotion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "user_emotion_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private Users users;

    @Column(nullable = false)
    @Enumerated(EnumType.STRING)
    private EmotionType emotion;

    @Column(nullable = false)
    private LocalDate date;

    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;

    private LocalDateTime updatedAt;

    @Builder
    public UserEmotion(Users users, EmotionType emotion, LocalDate date) {
        this.users = users;
        this.emotion = emotion;
        this.date = date;
    }

    public void updateEmotion(EmotionType emotion) {
        this.emotion = emotion;
        this.updatedAt = LocalDateTime.now();
    }
}
