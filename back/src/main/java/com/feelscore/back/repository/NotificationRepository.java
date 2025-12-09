package com.feelscore.back.repository;

import com.feelscore.back.entity.Notification;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface NotificationRepository extends JpaRepository<Notification, Long> {

    // 안 읽은 알림 최신순 조회
    List<Notification> findByUserIdAndIsReadFalseOrderByCreatedAtDesc(Long userId);

    // 전체 알림 최신순 조회 (필요 시)
    List<Notification> findByUserIdOrderByCreatedAtDesc(Long userId);
}
