package com.feelscore.back.dto;

import com.feelscore.back.entity.DmFolder;
import com.feelscore.back.entity.DmMemberState;
import com.feelscore.back.entity.DmMessage;
import com.feelscore.back.entity.DmThreadMember;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Getter
@NoArgsConstructor
public class DmThreadSummaryResponse {

    private Long threadId;

    // 상대 유저 정보
    private Long otherUserId;
    private String otherUserNickname;

    // 마지막 메시지 정보
    private Long lastMessageId;
    private String lastMessageContent;
    private LocalDateTime lastMessageTime;

    // 내 상태 정보
    private boolean hidden;
    private DmMemberState state;
    private DmFolder folder;
    private Long lastReadMessageId;

    public DmThreadSummaryResponse(DmThreadMember myMember) {
        this.threadId = myMember.getThread().getId();
        this.hidden = myMember.isHidden();
        this.state = myMember.getState();
        this.folder = myMember.getFolder();

        if (myMember.getLastReadMessage() != null) {
            this.lastReadMessageId = myMember.getLastReadMessage().getId();
        }

        // 상대방 찾기: "나와 다른 user를 가진 멤버"
        this.otherUserId = 0L; // fallback
        this.otherUserNickname = "(알 수 없음)";

        Long myUserId = myMember.getUser().getId();

        for (DmThreadMember member : myMember.getThread().getMembers()) {
            if (!member.getUser().getId().equals(myUserId)) {
                this.otherUserId = member.getUser().getId();
                this.otherUserNickname = member.getUser().getNickname();
                break;
            }
        }

        // 마지막 메시지 정보
        // 마지막 메시지 정보
        try {
            DmMessage lastMessage = myMember.getThread().getLastMessage();
            if (lastMessage != null) {
                this.lastMessageId = lastMessage.getId();
                this.lastMessageContent = lastMessage.getContent();
                this.lastMessageTime = lastMessage.getCreatedAt();
            }
        } catch (jakarta.persistence.EntityNotFoundException e) {
            // 마지막 메시지가 DB에 없으면(삭제됨 등) 무시
            this.lastMessageContent = "(삭제된 메시지)";
        }
    }
}
