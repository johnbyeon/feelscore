package com.feelscore.back.controller;

import com.feelscore.back.dto.BlockDto;
import com.feelscore.back.security.CustomUserDetails;
import com.feelscore.back.service.BlockService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/blocks")
@RequiredArgsConstructor
public class BlockController {

    private final BlockService blockService;

    /**
     * 특정 유저 차단 (로그인 유저 -> blockedId)
     * POST /api/blocks/{blockedId}
     */
    @PostMapping("/{blockedId}")
    public ResponseEntity<Void> blockUser(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long blockedId) {
        Long blockerId = userDetails.getUserId();
        blockService.blockUser(blockerId, blockedId);
        return ResponseEntity.ok().build();
    }

    /**
     * 차단 해제
     * DELETE /api/blocks/{blockedId}
     */
    @DeleteMapping("/{blockedId}")
    public ResponseEntity<Void> unblockUser(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long blockedId) {
        Long blockerId = userDetails.getUserId();
        blockService.unblockUser(blockerId, blockedId);
        return ResponseEntity.ok().build();
    }

    /**
     * 내 차단 목록 조회
     * GET /api/blocks
     */
    @GetMapping
    public ResponseEntity<List<BlockDto>> getBlockList(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        Long userId = userDetails.getUserId();
        return ResponseEntity.ok(blockService.getBlockList(userId));
    }
}
