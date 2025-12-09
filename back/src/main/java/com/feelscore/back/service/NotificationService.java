package com.feelscore.back.service;

import com.feelscore.back.entity.Notification;
import com.feelscore.back.entity.Users;
import com.feelscore.back.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final NotificationProducer notificationProducer;

    /**
     * 내 알림 목록 조회
     * - 최신순 정렬
     */
    public List<Notification> getMyNotifications(Long userId) {
        return notificationRepository.findByUserIdOrderByCreatedAtDesc(userId);
    }

    /**
     * 알림 생성 (다른 서비스에서 호출)
     */
    @Transactional
    public void createNotification(Users user, String type, String message, String relatedUrl) {
        Notification notification = Notification.create(user, type, message, relatedUrl);
        notificationRepository.save(notification);

        // 🔥 FCM 알림 발송 (토큰이 있는 경우에만)
        if (user.getFcmToken() != null) {
            try {
                com.feelscore.back.dto.FCMRequestDto fcmRequest = new com.feelscore.back.dto.FCMRequestDto();
                fcmRequest.setTargetToken(user.getFcmToken());

                // 타입별 제목 설정
                String title = "새로운 알림";
                if ("DM".equalsIgnoreCase(type)) {
                    title = "새로운 메시지";
                }

                fcmRequest.setTitle(title);
                fcmRequest.setBody(message);

                notificationProducer.sendNotification(fcmRequest);
            } catch (Exception e) {
                // 알림 발송 실패가 메인 로직(DB 저장)을 방해하면 안 됨
                System.err.println("Failed to send FCM notification: " + e.getMessage());
            }
        }
    }
}
