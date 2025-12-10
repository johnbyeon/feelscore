package com.feelscore.back.repository;

import com.feelscore.back.entity.Notification;
import com.feelscore.back.entity.Users;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NotificationRepository extends JpaRepository<Notification, Long> {
    Page<Notification> findByRecipientOrderByCreatedAtDesc(Users recipient, Pageable pageable);
}
