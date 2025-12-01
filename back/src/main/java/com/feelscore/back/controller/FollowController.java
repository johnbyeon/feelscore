package com.feelscore.back.controller;

import com.feelscore.back.service.FollowService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/follows")
@RequiredArgsConstructor
public class FollowController {

    private final FollowService followService;

    @PostMapping("/{followingId}")
    public ResponseEntity<Void> follow(@PathVariable Long followingId,
            @RequestParam Long userId) {
        followService.follow(userId, followingId);
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/{followingId}")
    public ResponseEntity<Void> unfollow(@PathVariable Long followingId,
            @RequestParam Long userId) {
        followService.unfollow(userId, followingId);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/users/{userId}/followers")
    public ResponseEntity<List<FollowService.FollowDto>> getFollowers(@PathVariable Long userId) {
        return ResponseEntity.ok(followService.getFollowers(userId));
    }

    @GetMapping("/users/{userId}/followings")
    public ResponseEntity<List<FollowService.FollowDto>> getFollowings(@PathVariable Long userId) {
        return ResponseEntity.ok(followService.getFollowings(userId));
    }
}
