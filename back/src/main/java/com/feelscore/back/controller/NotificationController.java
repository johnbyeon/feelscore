package com.feelscore.back.controller;

import com.feelscore.back.service.NotificationService;
import com.feelscore.back.security.CustomUserDetails;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

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
         * - 최신순으로 정렬된 알림 목록을 반환 (페이징)
         */
        @GetMapping
        public ResponseEntity<org.springframework.data.domain.Page<com.feelscore.back.dto.NotificationDto.Response>> getNotifications(
                        @AuthenticationPrincipal CustomUserDetails userDetails,
                        org.springframework.data.domain.Pageable pageable) {

                return ResponseEntity.ok(notificationService.getMyNotifications(userDetails.getUser(), pageable));
        }

        @GetMapping("/unread-count")
        public ResponseEntity<Long> getUnreadNotificationCount(@AuthenticationPrincipal CustomUserDetails userDetails) {
                long count = notificationService.getUnreadNotificationCount(userDetails.getUser());
                return ResponseEntity.ok(count);
        }

        @org.springframework.web.bind.annotation.PostMapping("/read-all")
        public ResponseEntity<Void> markAllAsRead(@AuthenticationPrincipal CustomUserDetails userDetails) {
                notificationService.markAllAsRead(userDetails.getUser());
                return ResponseEntity.ok().build();
        }

        @org.springframework.web.bind.annotation.DeleteMapping
        public ResponseEntity<Void> clearAllNotifications(@AuthenticationPrincipal CustomUserDetails userDetails) {
                notificationService.clearMyNotifications(userDetails.getUser());
                return ResponseEntity.ok().build();
        }
}
