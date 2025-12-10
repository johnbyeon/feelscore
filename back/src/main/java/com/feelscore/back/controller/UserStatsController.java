package com.feelscore.back.controller;

import com.feelscore.back.dto.UserEmotionStatsDto;
import com.feelscore.back.service.UserStatsService;
import com.feelscore.back.security.CustomUserDetails;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserStatsController {

    private final UserStatsService userStatsService;

    @GetMapping("/me/emotion-stats")
    public ResponseEntity<UserEmotionStatsDto> getMyEmotionStats(Authentication authentication) {
        CustomUserDetails userDetails = (CustomUserDetails) authentication.getPrincipal();
        UserEmotionStatsDto stats = userStatsService.getUserEmotionStats(userDetails.getUserId());
        return ResponseEntity.ok(stats);
    }
}
