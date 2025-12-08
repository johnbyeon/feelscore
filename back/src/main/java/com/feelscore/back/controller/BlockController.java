package com.feelscore.back.controller;

import com.feelscore.back.dto.BlockDto;
import com.feelscore.back.service.BlockService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/blocks")
@RequiredArgsConstructor
public class BlockController {

    private final BlockService blockService;

    // 유저 차단
    @PostMapping("/{blockedId}")
    public ResponseEntity<Void> blockUser(@PathVariable Long blockedId,
            @RequestParam Long userId) {
        blockService.blockUser(userId, blockedId);
        return ResponseEntity.ok().build();
    }

    // 차단 해제
    @DeleteMapping("/{blockedId}")
    public ResponseEntity<Void> unblockUser(@PathVariable Long blockedId,
            @RequestParam Long userId) {
        blockService.unblockUser(userId, blockedId);
        return ResponseEntity.ok().build();
    }

    // 차단 목록 조회
    @GetMapping
    public ResponseEntity<List<BlockDto>> getBlockList(@RequestParam Long userId) {
        return ResponseEntity.ok(blockService.getBlockList(userId));
    }
}
