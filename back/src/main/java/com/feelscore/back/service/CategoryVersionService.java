package com.feelscore.back.service;

import com.feelscore.back.dto.CategoryDto;
import com.feelscore.back.entity.Category;
import com.feelscore.back.entity.CategoryVersion;
import com.feelscore.back.repository.CategoryRepository;
import com.feelscore.back.repository.CategoryVersionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CategoryVersionService {

    private final CategoryVersionRepository categoryVersionRepository;
    private final CategoryRepository categoryRepository;

    /**
     * 새로운 버전 생성 (현재 모든 카테고리 스냅샷 저장)
     */
    @Transactional
    public Long createVersion(String description) {
        // 1. 현재 모든 카테고리 조회
        List<Category> allCategories = categoryRepository.findAll();

        // 2. 최신 버전 번호 조회 및 증가
        Long nextVersion = categoryVersionRepository.findMaxVersion().orElse(0L) + 1;

        // 3. 새 버전 생성
        CategoryVersion newVersion = CategoryVersion.builder()
                .version(nextVersion)
                .description(description)
                .categories(allCategories)
                .build();

        categoryVersionRepository.save(newVersion);

        return newVersion.getVersion();
    }

    /**
     * 모든 버전 목록 조회
     */
    public List<CategoryVersionDto> getAllVersions() {
        return categoryVersionRepository.findAll().stream()
                .map(CategoryVersionDto::from)
                .collect(Collectors.toList());
    }

    /**
     * 특정 버전의 카테고리 목록 조회
     */
    public List<CategoryDto.Response> getCategoriesByVersion(Long version) {
        CategoryVersion categoryVersion = categoryVersionRepository.findAll().stream()
                .filter(v -> v.getVersion().equals(version))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("해당 버전을 찾을 수 없습니다. version=" + version));

        return categoryVersion.getCategories().stream()
                .map(CategoryDto.Response::from)
                .collect(Collectors.toList());
    }

    // DTO for Version List
    @lombok.Getter
    @lombok.Builder
    public static class CategoryVersionDto {
        private Long id;
        private Long version;
        private String description;
        private String createdAt;

        public static CategoryVersionDto from(CategoryVersion entity) {
            return CategoryVersionDto.builder()
                    .id(entity.getId())
                    .version(entity.getVersion())
                    .description(entity.getDescription())
                    .createdAt(entity.getCreatedAt() != null ? entity.getCreatedAt().toString() : null)
                    .build();
        }
    }
}
