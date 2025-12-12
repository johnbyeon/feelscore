package com.feelscore.back.service;

import com.feelscore.back.config.RabbitMQConfig;
import com.feelscore.back.dto.FCMRequestDto;
import com.feelscore.back.dto.NotificationEventDto;
import com.feelscore.back.entity.Notification;
import com.feelscore.back.entity.Users;
import com.feelscore.back.repository.NotificationRepository;
import com.feelscore.back.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class NotificationConsumer {

    private final FCMService fcmService;
    private final NotificationRepository notificationRepository;
    private final UserRepository userRepository;

    @RabbitListener(queues = RabbitMQConfig.FCM_QUEUE_NAME)
    @Transactional
    public void receiveMessage(NotificationEventDto eventDto) {
        System.out.println("Message received from RabbitMQ: " + eventDto.getTitle());

        // 1. 사용자 조회
        Users recipient = userRepository.findById(eventDto.getRecipientId()).orElse(null);
        Users sender = userRepository.findById(eventDto.getSenderId()).orElse(null);

        if (recipient == null || sender == null) {
            System.err.println("Recipient or Sender not found. Skipping notification.");
            return;
        }

        // 2. DB 저장 (History)
        Notification notification = Notification.builder()
                .recipient(recipient)
                .sender(sender)
                .type(eventDto.getType())
                .content(eventDto.getBody())
                .relatedId(eventDto.getRelatedId())
                .build();
        notificationRepository.save(notification);

        // 3. FCM 발송 (토큰이 있는 경우만)
        if (recipient.getFcmToken() != null) {
            FCMRequestDto fcmRequest = new FCMRequestDto();
            fcmRequest.setTargetToken(recipient.getFcmToken());
            fcmRequest.setTitle(eventDto.getTitle());
            fcmRequest.setBody(eventDto.getBody());

            java.util.Map<String, String> data = new java.util.HashMap<>();
            data.put("senderId", String.valueOf(sender.getId()));
            if (eventDto.getRelatedId() != null) {
                data.put("threadId", String.valueOf(eventDto.getRelatedId()));
            }
            // Add notification type
            data.put("type", eventDto.getType() != null ? eventDto.getType().toString() : "");

            fcmRequest.setData(data);

            String response = fcmService.sendNotification(fcmRequest);
            System.out.println("FCM Response: " + response);
        }
    }
}
