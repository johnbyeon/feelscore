package com.feelscore.back.controller;

import com.feelscore.back.dto.CategoryDto;
import com.feelscore.back.service.CategoryVersionService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/categories/versions")
@RequiredArgsConstructor
public class CategoryVersionController {

    private final CategoryVersionService categoryVersionService;

    @PostMapping
    public ResponseEntity<Map<String, Long>> createVersion(@RequestBody Map<String, String> request) {
        String description = request.get("description");
        Long version = categoryVersionService.createVersion(description);
        return ResponseEntity.ok(Map.of("version", version));
    }

    @GetMapping
    public ResponseEntity<List<CategoryVersionService.CategoryVersionDto>> getAllVersions() {
        return ResponseEntity.ok(categoryVersionService.getAllVersions());
    }

    @GetMapping("/{version}")
    public ResponseEntity<List<CategoryDto.Response>> getCategoriesByVersion(@PathVariable Long version) {
        return ResponseEntity.ok(categoryVersionService.getCategoriesByVersion(version));
    }
}
