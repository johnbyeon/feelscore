package com.feelscore.back.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "comments")
public class Comment extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "comment_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "post_id", nullable = false)
    private Post post;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private Users users;

    @Column(columnDefinition = "TEXT", nullable = false)
    private String content;

    @Builder
    public Comment(Post post, Users users, String content) {
        this.post = post;
        this.users = users;
        this.content = content;
    }

    public void updateContent(String content) {
        this.content = content;
    }
}
