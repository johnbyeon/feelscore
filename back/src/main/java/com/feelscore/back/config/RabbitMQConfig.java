package com.feelscore.back.config;

import org.springframework.amqp.core.Binding;
import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.core.TopicExchange;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitMQConfig {

    // 기존 포스트 분석용
    public static final String QUEUE_NAME = "q.post.analysis";
    public static final String EXCHANGE_NAME = "x.post.analysis";
    public static final String ROUTING_KEY = "k.post.analyze";

    // 🔹 FCM 알림용 설정 추가
    public static final String FCM_QUEUE_NAME = "q.fcm.notification";
    public static final String FCM_EXCHANGE_NAME = "x.fcm.notification";
    public static final String FCM_ROUTING_KEY = "k.fcm.send";

    // ==========================================
    // 1. Post Analysis Queue & Exchange
    // ==========================================
    @Bean
    public Queue queue() {
        return new Queue(QUEUE_NAME, true); // Durable queue
    }

    @Bean
    public TopicExchange exchange() {
        return new TopicExchange(EXCHANGE_NAME);
    }

    @Bean
    public Binding binding(@Qualifier("queue") Queue queue,
            @Qualifier("exchange") TopicExchange exchange) {
        return BindingBuilder.bind(queue).to(exchange).with(ROUTING_KEY);
    }

    // ==========================================
    // 2. FCM Notification Queue & Exchange
    // ==========================================
    @Bean
    public Queue fcmQueue() {
        return new Queue(FCM_QUEUE_NAME, true);
    }

    @Bean
    public TopicExchange fcmExchange() {
        return new TopicExchange(FCM_EXCHANGE_NAME);
    }

    @Bean
    public Binding fcmBinding(@Qualifier("fcmQueue") Queue queue,
            @Qualifier("fcmExchange") TopicExchange exchange) {
        return BindingBuilder.bind(queue).to(exchange).with(FCM_ROUTING_KEY);
    }

    // ==========================================
    // Common
    // ==========================================
    @Bean
    public MessageConverter jsonMessageConverter() {
        return new Jackson2JsonMessageConverter();
    }

    @Bean
    public RabbitTemplate rabbitTemplate(ConnectionFactory connectionFactory) {
        RabbitTemplate rabbitTemplate = new RabbitTemplate(connectionFactory);
        rabbitTemplate.setMessageConverter(jsonMessageConverter());
        return rabbitTemplate;
    }
}