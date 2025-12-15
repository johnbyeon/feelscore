package com.feelscore.back.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 활성(웹소켓 연결) 유저 관리 서비스
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class ActiveUserService {

    private final SimpMessagingTemplate messagingTemplate;
    private final Set<Long> activeUserIds = ConcurrentHashMap.newKeySet();

    public void addActiveUser(Long userId) {
        if (userId != null) {
            activeUserIds.add(userId);
            log.info("User Online: {}", userId);
            broadcastUserStatus(userId, "ONLINE");
        }
    }

    public void removeActiveUser(Long userId) {
        if (userId != null) {
            activeUserIds.remove(userId);
            log.info("User Offline: {}", userId);
            broadcastUserStatus(userId, "OFFLINE");
        }
    }

    private void broadcastUserStatus(Long userId, String status) {
        try {
            java.util.Map<String, Object> payload = new java.util.HashMap<>();
            payload.put("type", "USER_STATUS");
            payload.put("userId", userId);
            payload.put("status", status);
            messagingTemplate.convertAndSend("/topic/public", payload);
        } catch (Exception e) {
            log.error("Failed to broadcast user status", e);
        }
    }

    public boolean isUserActive(Long userId) {
        return activeUserIds.contains(userId);
    }

    public int getActiveUserCount() {
        return activeUserIds.size();
    }
}
