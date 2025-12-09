package com.feelscore.back.service;

import com.feelscore.back.config.RabbitMQConfig;
import com.feelscore.back.dto.FCMRequestDto;
import lombok.RequiredArgsConstructor;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class NotificationConsumer {

    private final FCMService fcmService;

    @RabbitListener(queues = RabbitMQConfig.FCM_QUEUE_NAME)
    public void receiveMessage(FCMRequestDto requestDto) {
        System.out.println("Message received from RabbitMQ: " + requestDto.getTitle());

        // 실제 FCM 발송
        String response = fcmService.sendNotification(requestDto);
        System.out.println("FCM Response: " + response);
    }
}
