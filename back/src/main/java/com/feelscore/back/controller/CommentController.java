package com.feelscore.back.controller;

import com.feelscore.back.dto.CommentDto;
import com.feelscore.back.security.CustomUserDetails;
import com.feelscore.back.service.CommentService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/posts/{postId}/comments")
@RequiredArgsConstructor
public class CommentController {

    private final CommentService commentService;

    @PostMapping
    public ResponseEntity<CommentDto.Response> createComment(
            @PathVariable Long postId,
            @RequestBody CommentDto.Request request,
            Authentication authentication) {
        CustomUserDetails userDetails = (CustomUserDetails) authentication.getPrincipal(); // Assuming logged in
        CommentDto.Response response = commentService.createComment(postId, userDetails.getUserId(),
                request.getContent());
        return ResponseEntity.ok(response);
    }

    @GetMapping
    public ResponseEntity<List<CommentDto.Response>> getComments(
            @PathVariable Long postId,
            Authentication authentication) {
        Long userId = (authentication != null && authentication.getPrincipal() instanceof CustomUserDetails)
                ? ((CustomUserDetails) authentication.getPrincipal()).getUserId()
                : null;
        return ResponseEntity.ok(commentService.getComments(postId, userId));
    }

    @PostMapping("/{commentId}/react")
    public ResponseEntity<Void> toggleReaction(
            @PathVariable Long commentId,
            @RequestBody java.util.Map<String, String> request,
            Authentication authentication) {
        CustomUserDetails userDetails = (CustomUserDetails) authentication.getPrincipal();
        com.feelscore.back.entity.EmotionType emotionType = com.feelscore.back.entity.EmotionType
                .valueOf(request.get("emotionType"));
        commentService.toggleCommentReaction(commentId, userDetails.getUserId(), emotionType);
        return ResponseEntity.ok().build();
    }
}
