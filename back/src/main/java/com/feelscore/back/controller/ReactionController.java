package com.feelscore.back.controller;

import com.feelscore.back.dto.ReactionDto;
import com.feelscore.back.security.CustomUserDetails;
import com.feelscore.back.service.ReactionService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/posts/{postId}/react")
@RequiredArgsConstructor
public class ReactionController {

    private final ReactionService reactionService;

    @PostMapping
    public ResponseEntity<Void> toggleReaction(
            @PathVariable Long postId,
            @RequestBody ReactionDto.Request request,
            Authentication authentication) {
        CustomUserDetails userDetails = (CustomUserDetails) authentication.getPrincipal();
        reactionService.toggleReaction(postId, userDetails.getUserId(), request.getEmotionType());
        return ResponseEntity.ok().build();
    }

    @GetMapping
    public ResponseEntity<ReactionDto.Stats> getReactionStats(
            @PathVariable Long postId,
            Authentication authentication) {
        Long userId = null;
        if (authentication != null && authentication.getPrincipal() instanceof CustomUserDetails) {
            userId = ((CustomUserDetails) authentication.getPrincipal()).getUserId();
        }
        return ResponseEntity.ok(reactionService.getReactionStats(postId, userId));
    }
}
