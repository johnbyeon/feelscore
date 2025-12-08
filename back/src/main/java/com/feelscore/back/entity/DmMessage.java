package com.feelscore.back.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "dm_messages")
public class DmMessage extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "message_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "thread_id", nullable = false)
    private DmThread thread;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sender_id", nullable = false)
    private Users sender;

    @Enumerated(EnumType.STRING)
    @Column(name = "message_type", nullable = false, length = 20)
    private DmMessageType messageType = DmMessageType.TEXT;

    @Lob
    @Column(columnDefinition = "TEXT", nullable = false)
    private String content;

    @Column(name = "image_url")
    private String imageUrl;

    @Column(name = "deleted", nullable = false)
    private boolean deleted = false;

    // == 연관관계 세터 ==
    void setThread(DmThread thread) {
        this.thread = thread;
    }

    // == 생성 메서드 ==

    public static DmMessage createText(DmThread thread, Users sender, String content) {
        DmMessage message = new DmMessage();
        message.thread = thread;
        message.sender = sender;
        message.content = content;
        message.messageType = DmMessageType.TEXT;
        return message;
    }

    public static DmMessage createImage(DmThread thread, Users sender, String imageUrl, String content) {
        DmMessage message = new DmMessage();
        message.thread = thread;
        message.sender = sender;
        message.imageUrl = imageUrl;
        message.content = content;
        message.messageType = DmMessageType.IMAGE;
        return message;
    }

    public void markDeleted() {
        this.deleted = true;
    }
}
