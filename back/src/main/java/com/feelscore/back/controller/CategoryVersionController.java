package com.feelscore.back.controller;

import com.feelscore.back.dto.CategoryDto;
import com.feelscore.back.service.CategoryVersionService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/category-versions")
@RequiredArgsConstructor
public class CategoryVersionController {

    private final CategoryVersionService categoryVersionService;

    /**
     * 최신 버전 정보 조회
     * GET /api/category-versions/latest
     */
    @GetMapping("/latest")
    public ResponseEntity<CategoryVersionService.CategoryVersionDto> getLatestVersion() {
        CategoryVersionService.CategoryVersionDto response = categoryVersionService.getLatestVersion();
        return ResponseEntity.ok(response);
    }

    /**
     * 특정 버전의 카테고리 목록 조회
     * GET /api/category-versions/{version}/categories
     */
    @GetMapping("/{version}/categories")
    public ResponseEntity<List<CategoryDto.Response>> getCategoriesByVersion(@PathVariable Long version) {
        List<CategoryDto.Response> response = categoryVersionService.getCategoriesByVersion(version);
        return ResponseEntity.ok(response);
    }
}
