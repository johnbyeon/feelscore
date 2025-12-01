package com.feelscore.back.controller;

import com.feelscore.back.entity.EmotionType;
import com.feelscore.back.service.CommentService;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/comments")
@RequiredArgsConstructor
public class CommentController {

    private final CommentService commentService;

    @PostMapping
    public ResponseEntity<Map<String, Long>> createComment(@RequestBody CreateCommentRequest request,
            @RequestParam Long userId) {
        Long commentId = commentService.createComment(request.getPostId(), userId, request.getContent(),
                request.getEmotion());
        return ResponseEntity.ok(Map.of("commentId", commentId));
    }

    @PostMapping("/{commentId}/reactions")
    public ResponseEntity<Void> addReaction(@PathVariable Long commentId,
            @RequestBody ReactionRequest request,
            @RequestParam Long userId) {
        commentService.addReaction(commentId, userId, request.getEmotion());
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/{commentId}/reactions")
    public ResponseEntity<Void> removeReaction(@PathVariable Long commentId,
            @RequestParam Long userId) {
        commentService.removeReaction(commentId, userId);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/post/{postId}")
    public ResponseEntity<List<CommentService.CommentResponse>> getCommentsByPost(@PathVariable Long postId) {
        return ResponseEntity.ok(commentService.getCommentsByPost(postId));
    }

    @Getter
    @NoArgsConstructor
    public static class CreateCommentRequest {
        private Long postId;
        private String content;
        private EmotionType emotion;
    }

    @Getter
    @NoArgsConstructor
    public static class ReactionRequest {
        private EmotionType emotion;
    }
}
