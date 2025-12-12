package com.feelscore.back.service;

import com.feelscore.back.dto.FCMRequestDto;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import org.springframework.stereotype.Service;

@lombok.extern.slf4j.Slf4j
@Service
public class FCMService {

    public String sendNotification(FCMRequestDto requestDto) {
        log.info("Attempting to send FCM Notification...");
        log.info("Target Token: {}", requestDto.getTargetToken());
        log.info("Title: {}, Body: {}", requestDto.getTitle(), requestDto.getBody());

        Message.Builder messageBuilder = Message.builder()
                .setToken(requestDto.getTargetToken())
                .setNotification(Notification.builder()
                        .setTitle(requestDto.getTitle())
                        .setBody(requestDto.getBody())
                        .build())
                .setAndroidConfig(com.google.firebase.messaging.AndroidConfig.builder()
                        // High Priority is Critical for Background Delivery
                        .setPriority(com.google.firebase.messaging.AndroidConfig.Priority.HIGH)
                        .setNotification(com.google.firebase.messaging.AndroidNotification.builder()
                                // Channel ID must match the one in Application
                                .setChannelId("feelscore_notification_channel_v1")
                                .build())
                        .build());

        if (requestDto.getData() != null && !requestDto.getData().isEmpty()) {
            messageBuilder.putAllData(requestDto.getData());
            log.info("Data Payload included: {}", requestDto.getData());
        }

        Message message = messageBuilder.build();

        try {
            String response = FirebaseMessaging.getInstance().send(message);
            log.info("✅ FCM Send Success! Message ID: {}", response);
            return response;
        } catch (Exception e) {
            log.error("❌ FCM Send Failed!", e);
            return "Error sending notification: " + e.getMessage();
        }
    }
}
