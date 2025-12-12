package com.feelscore.back.controller;

import com.feelscore.back.dto.DmMessageResponse;
import com.feelscore.back.dto.DmSendMessageRequest;
import com.feelscore.back.entity.DmMessage;
import com.feelscore.back.security.CustomUserDetails;
import com.feelscore.back.service.DmService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestBody;

import java.security.Principal;

@Slf4j
@Controller
@RequiredArgsConstructor
public class DmMessageController {

    private final SimpMessagingTemplate messagingTemplate;
    private final DmService dmService;

    /**
     * 클라이언트가 /pub/chat/send 로 메시지를 보내면 처리
     */
    @MessageMapping("/chat/send")
    public void sendMessage(DmSendMessageRequest request, Principal principal) {
        // Principal은 StompHandler에서 세팅한 Authentication 객체
        if (principal == null) {
            log.error("❌ STOMP sendMessage: Principal is null");
            return;
        }

        log.info("ℹ️ STOMP Principal Name: {}", principal.getName());
        log.info("ℹ️ STOMP Principal Type: {}", principal.getClass().getName());

        Long senderId = null;
        if (principal instanceof org.springframework.security.authentication.UsernamePasswordAuthenticationToken token) {
            if (token.getPrincipal() instanceof CustomUserDetails userDetails) {
                senderId = userDetails.getUserId();
                log.info("✅ Resolved Sender ID from Principal: {}", senderId);
            } else {
                log.warn("⚠️ Token Principal is not CustomUserDetails: {}", token.getPrincipal().getClass().getName());
            }
        } else {
            log.warn("⚠️ Principal is not UsernamePasswordAuthenticationToken: {}", principal.getClass().getName());
        }

        if (senderId == null) {
            log.error("❌ STOMP sendMessage: Cannot identify sender");
            return;
        }

        log.info("📨 STOMP Message Processing: senderId={}, receiverId={}, threadId={}, content={}",
                senderId, request.getReceiverId(), request.getThreadId(), request.getContent());

        try {
            // 1. DB 저장 및 로직 수행 (DmService 재활용)
            DmMessage message = dmService.sendMessage(
                    senderId,
                    request.getReceiverId(),
                    request.getThreadId(),
                    request.getContent());

            // 2. 응답 DTO 생성
            DmMessageResponse response = new DmMessageResponse(message, senderId);

            // 3. 채팅방 구독자들에게 전송 (/sub/chat/room/{threadId})
            // threadId는 메시지 생성 시 확정되므로 message.getThread().getId() 사용
            messagingTemplate.convertAndSend(
                    "/sub/chat/room/" + message.getThread().getId(),
                    response);

        } catch (Exception e) {
            log.error("Error processing STOMP message: ", e);
            // 에러 발생 시 발송자에게만 에러 메시지 전송하는 로직 추가 가능 (/queue/errors)
        }
    }
}
