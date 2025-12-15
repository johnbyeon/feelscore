package com.feelscore.back.service;

import com.feelscore.back.dto.NotificationDto;
import com.feelscore.back.entity.Notification;
import com.feelscore.back.entity.NotificationType;
import com.feelscore.back.entity.Users;
import com.feelscore.back.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final NotificationProducer notificationProducer;
    private final com.feelscore.back.repository.UserRepository userRepository;

    /**
     * 내 알림 목록 조회
     * - 최신순 정렬
     */
    public Page<NotificationDto.Response> getMyNotifications(Users user, Pageable pageable) {
        Page<Notification> notifications = notificationRepository.findByRecipientOrderByCreatedAtDesc(user, pageable);
        return notifications.map(NotificationDto.Response::from);
    }

    @Transactional(readOnly = true)
    public long getUnreadNotificationCount(Users user) {
        long count = notificationRepository.countByRecipientIdAndIsReadFalse(user.getId());
        System.out.println("DEBUG_BACKEND: getUnreadNotificationCount for user " + user.getId() + " = " + count);
        return count;
    }

    @Transactional
    public void markAllAsRead(Users user) {
        System.out.println("DEBUG_BACKEND: markAllAsRead (Entity Strategy) STARTED for user " + user.getId());
        java.util.List<Notification> unreadList = notificationRepository.findAllByRecipientAndIsReadFalse(user);
        for (Notification n : unreadList) {
            n.markAsRead();
        }
        // Dirty checking will automatically save changes at the end of transaction
        System.out.println(
                "DEBUG_BACKEND: markAllAsRead (Entity Strategy) UPDATED " + unreadList.size() + " notifications.");
    }

    @Transactional
    public void clearMyNotifications(Users user) {
        notificationRepository.deleteByRecipient(user);
    }

    /**
     * 알림 발송 (Producer로 이벤트 발행)
     * - DB 저장은 Consumer에서 처리됨
     */
    public void sendNotification(Users sender, Users recipient, NotificationType type, String content, Long relatedId) {
        if (recipient.getId().equals(sender.getId())) {
            return; // 본인에게 알림 발송 X
        }

        com.feelscore.back.dto.NotificationEventDto eventDto = com.feelscore.back.dto.NotificationEventDto.builder()
                .recipientId(recipient.getId())
                .senderId(sender.getId())
                .type(type)
                .relatedId(relatedId)
                .title(getTitleByType(type))
                .body(content)
                .build();

        notificationProducer.sendNotification(eventDto);
    }

    private String getTitleByType(NotificationType type) {
        switch (type) {
            case DM:
                return "새로운 메시지";
            case POST_REACTION:
                return "새로운 반응이 있습니다!";
            case COMMENT_REACTION:
                return "새로운 반응이 있습니다!";
            case COMMENT:
                return "새로운 댓글이 달렸습니다!";
            case FOLLOW:
                return "새로운 팔로워!";
            default:
                return "새로운 알림";
        }
    }

    @Transactional
    public void deleteAllNotificationsByUser(Long userId) {
        Users user = userRepository.findById(userId).orElseThrow();
        notificationRepository.deleteByRecipient(user);
        notificationRepository.deleteBySender(user);
    }
}
