package com.feelscore.back.config;

import com.feelscore.back.myjwt.JwtTokenService;
import com.feelscore.back.security.CustomUserDetailsService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageBuilder;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;

import java.util.Optional;

@Slf4j
@Component
@RequiredArgsConstructor
public class StompHandler implements ChannelInterceptor {

    private final JwtTokenService jwtTokenService;
    private final CustomUserDetailsService userDetailsService;

    @Override
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
        if (accessor == null) {
            accessor = StompHeaderAccessor.wrap(message);
        }

        // Websocket 연결 시, 메시지 전송 시, 구독 시 모두 토큰 검증
        if (StompCommand.CONNECT.equals(accessor.getCommand()) ||
                StompCommand.SEND.equals(accessor.getCommand()) ||
                StompCommand.SUBSCRIBE.equals(accessor.getCommand())) {

            String token = Optional.ofNullable(accessor.getFirstNativeHeader("Authorization"))
                    .map(header -> header.startsWith("Bearer ") ? header.substring(7) : header)
                    .orElse(null);

            if (token != null) {
                try {
                    if (jwtTokenService.isExpired(token)) {
                        log.warn("STOMP Token Expired for command {}", accessor.getCommand());
                        throw new IllegalArgumentException("Expired Token");
                    }

                    String email = jwtTokenService.extractEmail(token);
                    if (email != null) {
                        UserDetails userDetails = userDetailsService.loadUserByUsername(email);
                        UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(userDetails,
                                null, userDetails.getAuthorities());

                        // WebSocket Session에 유저 정보 저장
                        accessor.setUser(auth);

                        // 중요: 헤더가 변경되었으므로 변경된 헤더를 포함한 새 메시지를 반환해야 함
                        accessor.setLeaveMutable(true); // 메시지 빌더 사용 위해

                        log.info("STOMP Authenticated {} for user={}", accessor.getCommand(), email);

                        // 기존 message가 불변일 수 있으므로 빌더로 새로 생성
                        return MessageBuilder.createMessage(message.getPayload(), accessor.getMessageHeaders());
                    }
                } catch (Exception e) {
                    log.error("STOMP Auth Error: {}", e.getMessage());
                    throw new IllegalArgumentException("Invalid Token");
                }
            } else {
                if (StompCommand.CONNECT.equals(accessor.getCommand())) {
                    log.error("No Authorization header in STOMP CONNECT");
                }
            }
        }
        return message;
    }
}
