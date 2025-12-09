package com.feelscore.back.service;

import com.feelscore.back.config.RabbitMQConfig;
import com.feelscore.back.dto.FCMRequestDto;
import lombok.RequiredArgsConstructor;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class NotificationProducer {

    private final RabbitTemplate rabbitTemplate;

    public void sendNotification(FCMRequestDto requestDto) {
        rabbitTemplate.convertAndSend(
                RabbitMQConfig.FCM_EXCHANGE_NAME,
                RabbitMQConfig.FCM_ROUTING_KEY,
                requestDto);
        System.out.println("Message sent to RabbitMQ: " + requestDto.getTitle());
    }
}
