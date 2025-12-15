package com.feelscore.back.controller;

import com.feelscore.back.dto.FollowDto;
import com.feelscore.back.dto.UsersDto;
import com.feelscore.back.entity.Users;
import com.feelscore.back.repository.UserRepository;
import com.feelscore.back.service.FollowService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;
import java.util.List;

@RestController
@RequestMapping("/api/follows")
@RequiredArgsConstructor
public class FollowController {

    private final FollowService followService;
    private final UserRepository userRepository;

    @PostMapping("/{targetId}")
    public ResponseEntity<Boolean> toggleFollow(@PathVariable Long targetId,
            Principal principal) {
        if (principal == null) {
            return ResponseEntity.status(401).build();
        }
        Users currentUser = userRepository.findByEmail(principal.getName())
                .orElseThrow(() -> new IllegalArgumentException("Invalid User"));

        boolean isFollowing = followService.toggleFollow(currentUser.getId(), targetId);
        return ResponseEntity.ok(isFollowing);
    }

    @GetMapping("/{targetId}/stats")
    public ResponseEntity<FollowDto.Stats> getStats(@PathVariable Long targetId,
            Principal principal) {
        Long currentUserId = null;
        if (principal != null) {
            Users user = userRepository.findByEmail(principal.getName()).orElse(null);
            if (user != null) {
                currentUserId = user.getId();
            }
        }

        FollowDto.Stats stats = followService.getStats(targetId, currentUserId);
        return ResponseEntity.ok(stats);
    }

    @GetMapping("/{targetId}/followers")
    public ResponseEntity<List<UsersDto.SimpleResponse>> getFollowers(
            @PathVariable Long targetId,
            @RequestParam(required = false) String query) {
        List<UsersDto.SimpleResponse> followers = followService.getFollowers(targetId, query);
        return ResponseEntity.ok(followers);
    }

    @GetMapping("/{targetId}/followings")
    public ResponseEntity<List<UsersDto.SimpleResponse>> getFollowings(
            @PathVariable Long targetId,
            @RequestParam(required = false) String query) {
        List<UsersDto.SimpleResponse> followings = followService.getFollowings(targetId, query);
        return ResponseEntity.ok(followings);
    }
}
