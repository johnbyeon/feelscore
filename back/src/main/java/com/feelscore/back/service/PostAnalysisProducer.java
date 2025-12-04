package com.feelscore.back.service;

import com.feelscore.back.config.RabbitMQConfig;
import com.feelscore.back.dto.PostAnalysisEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class PostAnalysisProducer {

    private final RabbitTemplate rabbitTemplate;

    public void sendAnalysisEvent(Long postId, String content) {
        PostAnalysisEvent event = PostAnalysisEvent.builder()
                .postId(postId)
                .content(content)
                .build();

        log.info("Sending analysis event for postId: {}", postId);
        rabbitTemplate.convertAndSend(
                RabbitMQConfig.EXCHANGE_NAME,
                RabbitMQConfig.ROUTING_KEY,
                event);
    }
}
