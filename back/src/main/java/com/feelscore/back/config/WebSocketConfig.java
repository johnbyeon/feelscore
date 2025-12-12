package com.feelscore.back.config;

import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

@Configuration
@EnableWebSocketMessageBroker
@RequiredArgsConstructor
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    private final StompHandler stompHandler;

    @Override
    public void configureMessageBroker(MessageBrokerRegistry config) {
        // 구독(sub) : 클라이언트가 메시지를 받을 경로
        // enableSimpleBroker에 Heartbeat 설정 추가 (10초)
        org.springframework.scheduling.concurrent.ThreadPoolTaskScheduler taskScheduler = new org.springframework.scheduling.concurrent.ThreadPoolTaskScheduler();
        taskScheduler.initialize();

        config.enableSimpleBroker("/sub", "/queue")
                .setTaskScheduler(taskScheduler)
                .setHeartbeatValue(new long[] { 10000, 10000 });

        // 발행(pub) : 클라이언트가 메시지를 보낼 경로 (Controller 매핑)
        config.setApplicationDestinationPrefixes("/pub");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        // 소켓 연결 엔드포인트
        registry.addEndpoint("/ws-stomp")
                .setAllowedOriginPatterns("*");
        // .withSockJS(); // Flutter는 SockJS를 기본 지원하지 않으므로 순수 WebSocket 사용 추천
    }

    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        // JWT 인증 인터셉터 추가
        registration.interceptors(stompHandler);
    }
}
