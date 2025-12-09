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
        @UniqueConstraint(columnNames = { "comment_id", "user_id" })
})
public class CommentReaction {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "reaction_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "comment_id", nullable = false)
    private Comment comment;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private Users users;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private EmotionType emotionType;

    @Builder
    public CommentReaction(Comment comment, Users users, EmotionType emotionType) {
        this.comment = comment;
        this.users = users;
        this.emotionType = emotionType;
    }

    public void updateEmotion(EmotionType emotionType) {
        this.emotionType = emotionType;
    }
}
