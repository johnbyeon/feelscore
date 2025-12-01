package com.feelscore.back.controller;

import com.feelscore.back.service.PostService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import static com.feelscore.back.dto.PostDto.*;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/posts")
public class PostController {

    private final PostService postService;

    /**
     * 게시글 생성
     * POST /api/v1/posts
     *
     * @param request 게시글 생성 요청 DTO
     * @param userId 게시글 작성자 ID
     * @return 생성된 게시글 상세 응답 DTO
     */
    @PostMapping
    public ResponseEntity<Response> createPost(
            @RequestBody @Valid CreateRequest request,
            @RequestParam Long userId
    ) {
        Response response = postService.createPost(request, userId);
        return ResponseEntity.ok(response);
    }

    /**
     * 단일 게시글 조회
     * GET /api/v1/posts/{postId}
     *
     * @param postId 조회할 게시글 ID
     * @return 게시글 상세 응답 DTO
     */
    @GetMapping("/{postId}")
    public ResponseEntity<Response> getPostById(@PathVariable Long postId) {
        Response response = postService.getPostById(postId);
        return ResponseEntity.ok(response);
    }

    /**
     * 특정 카테고리 게시글 목록 조회 (페이징)
     * GET /api/v1/posts/category/{categoryId}
     *
     * @param categoryId 조회할 카테고리 ID
     * @param pageable 페이징 정보 (size, page, sort)
     * @return 게시글 목록 응답 DTO (페이징 포함)
     */
    @GetMapping("/category/{categoryId}")
    public ResponseEntity<Page<ListResponse>> getPostsByCategory(
            @PathVariable Long categoryId,
            @PageableDefault(sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable
    ) {
        Page<ListResponse> responses = postService.getPostsByCategory(categoryId, pageable);
        return ResponseEntity.ok(responses);
    }

    /**
     * 특정 사용자 게시글 목록 조회 (페이징)
     * GET /api/v1/posts/user/{userId}
     *
     * @param userId 조회할 사용자 ID
     * @param pageable 페이징 정보 (size, page, sort)
     * @return 게시글 목록 응답 DTO (페이징 포함)
     */
    @GetMapping("/user/{userId}")
    public ResponseEntity<Page<ListResponse>> getPostsByUser(
            @PathVariable Long userId,
            @PageableDefault(sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable
    ) {
        Page<ListResponse> responses = postService.getPostsByUser(userId, pageable);
        return ResponseEntity.ok(responses);
    }

    /**
     * 게시글 수정
     * PUT /api/v1/posts/{postId}
     *
     * @param postId 수정할 게시글 ID
     * @param request 게시글 수정 요청 DTO
     * @param userId 요청한 사용자 ID (작성자 확인용)
     * @return 수정된 게시글 상세 응답 DTO
     */
    @PutMapping("/{postId}")
    public ResponseEntity<Response> updatePost(
            @PathVariable Long postId,
            @RequestBody @Valid UpdateRequest request,
            @RequestParam Long userId
    ) {
        Response response = postService.updatePost(postId, request, userId);
        return ResponseEntity.ok(response);
    }

    /**
     * 게시글 삭제 (상태 변경)
     * DELETE /api/v1/posts/{postId}
     *
     * @param postId 삭제할 게시글 ID
     * @param userId 요청한 사용자 ID (작성자 확인용)
     * @return HTTP 204 No Content
     */
    @DeleteMapping("/{postId}")
    public ResponseEntity<Void> deletePost(
            @PathVariable Long postId,
            @RequestParam Long userId
    ) {
        postService.deletePost(postId, userId);
        return ResponseEntity.noContent().build();
    }
}
