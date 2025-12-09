package com.feelscore.back.controller;

import com.feelscore.back.dto.NotificationResponse;
import com.feelscore.back.entity.Notification;
import com.feelscore.back.service.NotificationService;
import com.feelscore.back.security.CustomUserDetails;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 알림 관련 API 컨트롤러
 * - 내 알림 목록 조회 등 알림 관련 기능을 제공함.
 */
@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationService notificationService;

    /**
     * 내 알림 목록 조회 API
     * - 최신순으로 정렬된 알림 목록을 반환
     */
    @GetMapping
    public ResponseEntity<List<NotificationResponse>> getNotifications(
            @AuthenticationPrincipal CustomUserDetails userDetails) {

        List<Notification> notifications = notificationService.getMyNotifications(userDetails.getUserId());

        List<NotificationResponse> response = notifications.stream()
                .map(NotificationResponse::new)
                .toList();

        return ResponseEntity.ok(response);
    }
}
