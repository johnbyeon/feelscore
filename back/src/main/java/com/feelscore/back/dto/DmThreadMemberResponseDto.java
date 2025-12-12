package com.feelscore.back.dto;

import com.feelscore.back.entity.DmFolder;
import com.feelscore.back.entity.DmMemberState;
import com.feelscore.back.entity.DmThreadMember;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Getter
@NoArgsConstructor
public class DmThreadMemberResponseDto {

    private Long threadId;
    private Long otherUserId;
    private String otherUserNickname;
    private String otherUserProfileImageUrl;

    private Long lastReadMessageId;
    private String lastMessageContent;
    private LocalDateTime lastMessageTime;

    private DmMemberState state;
    private DmFolder folder;

    private long unreadCount;

    public DmThreadMemberResponseDto(DmThreadMember member, DmThreadMember otherMember, long unreadCount) {
        this.threadId = member.getThread().getId();
        this.otherUserId = otherMember.getUser().getId();
        this.otherUserNickname = otherMember.getUser().getNickname();
        this.otherUserProfileImageUrl = otherMember.getUser().getProfileImageUrl();

        if (member.getLastReadMessage() != null) {
            this.lastReadMessageId = member.getLastReadMessage().getId();
        }

        if (member.getThread().getLastMessage() != null) {
            this.lastMessageContent = member.getThread().getLastMessage().getContent();
            this.lastMessageTime = member.getThread().getLastMessage().getCreatedAt();
        }

        this.state = member.getState();
        this.folder = member.getFolder();
        this.unreadCount = unreadCount;
    }
}
