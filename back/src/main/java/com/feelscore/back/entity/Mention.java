package com.feelscore.back.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "mentions")
public class Mention extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "mention_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "mentioned_user_id", nullable = false)
    private Users mentionedUser; // 태그된 유저

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "mentioner_id", nullable = false)
    private Users mentioner; // 태그한 유저

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "post_id")
    private Post post; // 태그된 게시글 (nullable - 댓글에서 태그된 경우)

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "comment_id")
    private Comment comment; // 태그된 댓글 (nullable - 게시글에서 태그된 경우)

    public static Mention createForPost(Users mentionedUser, Users mentioner, Post post) {
        Mention mention = new Mention();
        mention.mentionedUser = mentionedUser;
        mention.mentioner = mentioner;
        mention.post = post;
        return mention;
    }

    public static Mention createForComment(Users mentionedUser, Users mentioner, Comment comment) {
        Mention mention = new Mention();
        mention.mentionedUser = mentionedUser;
        mention.mentioner = mentioner;
        mention.comment = comment;
        mention.post = comment.getPost(); // 댓글이 달린 게시글도 저장
        return mention;
    }
}
