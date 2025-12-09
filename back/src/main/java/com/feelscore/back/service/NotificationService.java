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
    }
}
