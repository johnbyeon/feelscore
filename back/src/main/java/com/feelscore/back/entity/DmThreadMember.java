package com.feelscore.back.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "dm_thread_members", uniqueConstraints = {
        @UniqueConstraint(name = "uk_dm_thread_member", columnNames = { "thread_id", "user_id" })
})
public class DmThreadMember extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "thread_member_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "thread_id", nullable = false)
    private DmThread thread;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private Users user;

    /**
     * NORMAL : 일반 DM 상태
     * REQUEST : 메시지 요청(비팔로우)
     * BLOCKED : 차단
     * DELETED : 내가 삭제한 상태
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "state", nullable = false, length = 20)
    private DmMemberState state = DmMemberState.NORMAL;

    /**
     * PRIMARY : 일반 DM함
     * REQUEST : 메시지 요청함
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "folder", nullable = false, length = 20)
    private DmFolder folder = DmFolder.PRIMARY;

    /**
     * true 이면 "내 화면"에서만 이 대화방을 숨김 (나가기/삭제)
     * 상대방 화면에는 그대로 남아 있음
     */
    @Column(name = "hidden", nullable = false)
    private boolean hidden = false;

    /**
     * 이 유저가 마지막으로 읽은 메시지
     * 읽음 표시, 안 읽은 개수 계산에 사용
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "last_read_message_id")
    private DmMessage lastReadMessage;

    // == 연관관계 세터 (편의용) ==
    void setThread(DmThread thread) {
        this.thread = thread;
    }

    void setUser(Users user) {
        this.user = user;
    }

    // == 비즈니스 메서드 ==

    public void changeState(DmMemberState state, DmFolder folder) {
        this.state = state;
        if (folder != null) {
            this.folder = folder;
        }
    }

    public void hide() {
        this.hidden = true;
    }

    public void unhide() {
        this.hidden = false;
    }

    public void updateLastRead(DmMessage message) {
        this.lastReadMessage = message;
    }

    public static DmThreadMember create(DmThread thread, Users user, DmMemberState state, DmFolder folder) {
        DmThreadMember member = new DmThreadMember();
        member.thread = thread;
        member.user = user;
        member.state = state;
        member.folder = folder;
        return member;
    }
}
