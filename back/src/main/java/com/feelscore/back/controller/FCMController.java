package com.feelscore.back.controller;

import com.feelscore.back.dto.FCMRequestDto;
import com.feelscore.back.service.NotificationProducer;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/fcm")
@RequiredArgsConstructor
public class FCMController {

    private final NotificationProducer notificationProducer;

    @PostMapping("/send")
    public ResponseEntity<String> sendNotification(@RequestBody FCMRequestDto requestDto) {
        // 큐에 넣기만 하고 바로 응답 (비동기 처리)
        notificationProducer.sendNotification(requestDto);
        return ResponseEntity.ok("Notification queued successfully");
    }
}
