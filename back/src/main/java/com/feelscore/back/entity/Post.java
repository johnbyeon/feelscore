package com.feelscore.back.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "posts")
public class Post extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "post_id")
    private Long id;

    @Column(name = "user_id")
    private Long user_id;

    @Lob // 긴 텍스트
    @Column(columnDefinition = "TEXT", nullable = false) // TEXT(65kb) 또는 LONGTEXT(4GB)
    private String content;

    @Enumerated(EnumType.STRING)
    private PostStatus status; // NORMAL, BLIND

    private String blindReason; // 블라인드 사유 (신고누적, 위험단어 등)

    // 연관관계
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private Users users;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id")
    private Category category;
}
