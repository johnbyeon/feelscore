package com.feelscore.back.repository;

import com.feelscore.back.entity.Notification;
import com.feelscore.back.entity.Users;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface NotificationRepository extends JpaRepository<Notification, Long> {
    Page<Notification> findByRecipientOrderByCreatedAtDesc(Users recipient, Pageable pageable);

    void deleteByRecipient(Users recipient);

    void deleteBySender(Users sender);

    long countByRecipientIdAndIsReadFalse(Long recipientId);

    List<Notification> findAllByRecipientAndIsReadFalse(Users recipient);

    @org.springframework.data.jpa.repository.Modifying(clearAutomatically = true, flushAutomatically = true)
    @org.springframework.data.jpa.repository.Query("UPDATE Notification n SET n.isRead = true WHERE n.recipient.id = :recipientId AND n.isRead = false")
    void markAllAsRead(@org.springframework.data.repository.query.Param("recipientId") Long recipientId);
}
