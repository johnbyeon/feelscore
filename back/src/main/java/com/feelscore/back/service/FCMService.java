package com.feelscore.back.service;

import com.feelscore.back.dto.FCMRequestDto;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import org.springframework.stereotype.Service;

@Service
public class FCMService {

    public String sendNotification(FCMRequestDto requestDto) {
        Message message = Message.builder()
                .setToken(requestDto.getTargetToken())
                .setNotification(Notification.builder()
                        .setTitle(requestDto.getTitle())
                        .setBody(requestDto.getBody())
                        .build())
                .build();

        try {
            return FirebaseMessaging.getInstance().send(message);
        } catch (Exception e) {
            e.printStackTrace();
            return "Error sending notification: " + e.getMessage();
        }
    }
}
