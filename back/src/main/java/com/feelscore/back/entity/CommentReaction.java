package com.feelscore.back.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "comment_reactions", uniqueConstraints = {
        @UniqueConstraint(name = "uk_comment_user_reaction", columnNames = { "comment_id", "user_id" })
})
public class CommentReaction extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "comment_reaction_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "comment_id", nullable = false)
    private Comment comment;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private Users users;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private EmotionType emotion; // 반응 감정 (좋아요 대신 감정 표현)

    @Builder
    public CommentReaction(Comment comment, Users users, EmotionType emotion) {
        this.comment = comment;
        this.users = users;
        this.emotion = emotion;
    }

    public void updateEmotion(EmotionType emotion) {
        this.emotion = emotion;
    }
}
