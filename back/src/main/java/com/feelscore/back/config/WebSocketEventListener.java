package com.feelscore.back.config;

import com.feelscore.back.security.CustomUserDetails;
import com.feelscore.back.service.ActiveUserService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.event.EventListener;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.messaging.SessionConnectedEvent;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

import java.security.Principal;

@Component
@RequiredArgsConstructor
@Slf4j
public class WebSocketEventListener {

    private final ActiveUserService activeUserService;

    @EventListener
    public void handleWebSocketConnectListener(SessionConnectedEvent event) {
        log.info("Received a new web socket connection");
        Principal principal = event.getUser();

        if (principal == null) {
            log.error("Principal is NULL!");
            return;
        }

        log.info("Principal Class: {}", principal.getClass().getName());
        log.info("Principal Name: {}", principal.getName());

        if (principal instanceof UsernamePasswordAuthenticationToken) {
            UsernamePasswordAuthenticationToken token = (UsernamePasswordAuthenticationToken) principal;
            Object p = token.getPrincipal();
            log.info("Token Principal Type: {}", p.getClass().getName());

            if (p instanceof CustomUserDetails) {
                CustomUserDetails userDetails = (CustomUserDetails) p;
                log.info(">>>> Adding Active User: {} (ID: {})", userDetails.getUsername(), userDetails.getUserId());
                activeUserService.addActiveUser(userDetails.getUserId());
                // Verify immediate add
                boolean added = activeUserService.isUserActive(userDetails.getUserId());
                log.info(">>>> Verification: Is User {} Active? {}", userDetails.getUserId(), added);
            } else {
                log.warn("Principal is not CustomUserDetails: " + p);
            }
        } else {
            log.warn("Principal is not UsernamePasswordAuthenticationToken: " + principal);
        }
    }

    @EventListener
    public void handleWebSocketDisconnectListener(SessionDisconnectEvent event) {
        Principal principal = event.getUser();
        if (principal instanceof UsernamePasswordAuthenticationToken) {
            UsernamePasswordAuthenticationToken token = (UsernamePasswordAuthenticationToken) principal;
            if (token.getPrincipal() instanceof CustomUserDetails) {
                CustomUserDetails userDetails = (CustomUserDetails) token.getPrincipal();
                log.info("User Disconnected: " + userDetails.getUsername());
                activeUserService.removeActiveUser(userDetails.getUserId());
            }
        }
    }
}
