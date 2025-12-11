package com.feelscore.back.service;

import com.feelscore.back.config.RabbitMQConfig;
import com.feelscore.back.dto.NotificationEventDto;
import lombok.RequiredArgsConstructor;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class NotificationProducer {

    private final RabbitTemplate rabbitTemplate;

    public void sendNotification(NotificationEventDto eventDto) {
        try {
            if (rabbitTemplate == null) {
                System.err.println("RabbitTemplate is null!");
                return;
            }
            rabbitTemplate.convertAndSend(
                    RabbitMQConfig.FCM_EXCHANGE_NAME,
                    RabbitMQConfig.FCM_ROUTING_KEY,
                    eventDto);
            System.out.println("Message sent to RabbitMQ: " + eventDto.getTitle());
        } catch (Throwable e) {
            System.err.println("Failed to send notification to RabbitMQ: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
