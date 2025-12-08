package com.feelscore.back.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.ArrayList;
import java.util.List;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "dm_threads")
public class DmThread extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "thread_id")
    private Long id;

    /**
     * 마지막 메시지 (목록 미리보기/정렬용 캐시)
     * null 일 수 있음
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "last_message_id")
    private DmMessage lastMessage;

    @OneToMany(mappedBy = "thread", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<DmThreadMember> members = new ArrayList<>();

    @OneToMany(mappedBy = "thread", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<DmMessage> messages = new ArrayList<>();

    // == 연관관계 편의 메서드 ==

    public void addMember(DmThreadMember member) {
        members.add(member);
        member.setThread(this);
    }

    public void addMessage(DmMessage message) {
        messages.add(message);
        message.setThread(this);
        this.lastMessage = message;
    }

    public void updateLastMessage(DmMessage message) {
        this.lastMessage = message;
    }

    public static DmThread create() {
        return new DmThread();
    }
}
