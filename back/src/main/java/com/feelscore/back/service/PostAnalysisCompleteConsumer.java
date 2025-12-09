package com.feelscore.back.service;

import com.feelscore.back.config.RabbitMQConfig;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class PostAnalysisCompleteConsumer {

    private final CategoryStatsService categoryStatsService;

    @RabbitListener(queues = RabbitMQConfig.ANALYSIS_COMPLETE_QUEUE)
    public void receiveMessage(Map<String, Object> message) {
        try {
            log.info("Received analysis complete event: {}", message);

            Object postIdObj = message.get("postId");
            Long postId;

            if (postIdObj instanceof Integer) {
                postId = ((Integer) postIdObj).longValue();
            } else if (postIdObj instanceof Long) {
                postId = (Long) postIdObj;
            } else {
                postId = Long.parseLong(postIdObj.toString());
            }

            categoryStatsService.updateStats(postId);
            log.info("Successfully updated stats for Post ID: {}", postId);
        } catch (Exception e) {
            log.error("Error processing analysis complete event", e);
        }
    }
}
