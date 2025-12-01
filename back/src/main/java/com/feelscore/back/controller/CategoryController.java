package com.feelscore.back.controller;

import com.feelscore.back.dto.CategoryDto;
import com.feelscore.back.service.CategoryService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/categories")
@RequiredArgsConstructor
public class CategoryController {

    private final CategoryService categoryService;

    /**
     * 카테고리 생성
     * POST /api/categories
     *
     * 예시 요청 JSON:
     * {
     *   "name": "직장",
     *   "depth": 1,
     *   "parentId": null
     * }
     *
     * {
     *   "name": "회사 인간관계",
     *   "depth": 2,
     *   "parentId": 1
     * }
     */
    @PostMapping
    public ResponseEntity<CategoryDto.Response> createCategory(
            @RequestBody @Valid CategoryDto.CreateRequest request
    ) {
        CategoryDto.Response response = categoryService.createCategory(request);
        return ResponseEntity.ok(response);
    }

    /**
     * 단일 카테고리 조회
     * GET /api/categories/{id}
     */
    @GetMapping("/{id}")
    public ResponseEntity<CategoryDto.Response> getCategory(@PathVariable Long id) {
        CategoryDto.Response response = categoryService.getCategory(id);
        return ResponseEntity.ok(response);
    }

    /**
     * 대분류 목록 조회
     * GET /api/categories/roots
     */
    @GetMapping("/roots")
    public ResponseEntity<List<CategoryDto.Response>> getRootCategories() {
        List<CategoryDto.Response> response = categoryService.getRootCategories();
        return ResponseEntity.ok(response);
    }

    /**
     * depth 로 카테고리 목록 조회
     * GET /api/categories/depth/{depth}
     *  - /api/categories/depth/1  → 대분류
     *  - /api/categories/depth/2  → 소분류
     */
    @GetMapping("/depth/{depth}")
    public ResponseEntity<List<CategoryDto.Response>> getByDepth(@PathVariable Integer depth) {
        List<CategoryDto.Response> response = categoryService.getCategoriesByDepth(depth);
        return ResponseEntity.ok(response);
    }

    /**
     * 특정 부모의 자식 카테고리 목록 조회
     * GET /api/categories/{id}/children
     */
    @GetMapping("/{id}/children")
    public ResponseEntity<List<CategoryDto.Response>> getChildren(@PathVariable Long id) {
        List<CategoryDto.Response> response = categoryService.getChildren(id);
        return ResponseEntity.ok(response);
    }

    /**
     * 카테고리 + 자식들까지 트리로 조회
     * GET /api/categories/{id}/tree
     */
    @GetMapping("/{id}/tree")
    public ResponseEntity<CategoryDto.ResponseWithChildren> getCategoryTree(@PathVariable Long id) {
        CategoryDto.ResponseWithChildren response = categoryService.getCategoryWithChildren(id);
        return ResponseEntity.ok(response);
    }
}
