package com.feelscore.back.service;

import com.feelscore.back.dto.CategoryDto;
import com.feelscore.back.entity.Category;
import com.feelscore.back.repository.CategoryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CategoryService {

    private final CategoryRepository categoryRepository;

    /**
     * 카테고리 생성
     * - depth = 1 이면 parentId 는 null 로 두고 대분류
     * - depth = 2 이면 parentId 로 부모 카테고리 찾아서 소분류 생성
     */
    @Transactional
    public CategoryDto.Response createCategory(CategoryDto.CreateRequest request) {
        Category parent = null;

        if (request.getParentId() != null) {
            parent = categoryRepository.findById(request.getParentId())
                    .orElseThrow(() -> new IllegalArgumentException("부모 카테고리를 찾을 수 없습니다. id=" + request.getParentId()));
        }

        Category category = request.toEntity(parent);
        Category saved = categoryRepository.save(category);

        return CategoryDto.Response.from(saved);
    }

    /**
     * 단일 카테고리 조회 (부모 id 만 포함)
     */
    public CategoryDto.Response getCategory(Long id) {
        Category category = categoryRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("카테고리를 찾을 수 없습니다. id=" + id));

        return CategoryDto.Response.from(category);
    }

    /**
     * 대분류 목록 조회 (parent 가 null 인 것들)
     */
    public List<CategoryDto.Response> getRootCategories() {
        return categoryRepository.findByParentIsNull().stream()
                .map(CategoryDto.Response::from)
                .toList();
    }

    /**
     * depth 로 카테고리 목록 조회
     * - depth = 1: 대분류
     * - depth = 2: 소분류
     */
    public List<CategoryDto.Response> getCategoriesByDepth(Integer depth) {
        return categoryRepository.findByDepth(depth).stream()
                .map(CategoryDto.Response::from)
                .toList();
    }

    /**
     * 특정 부모 카테고리의 자식(소분류) 목록 조회
     */
    public List<CategoryDto.Response> getChildren(Long parentId) {
        return categoryRepository.findByParent_Id(parentId).stream()
                .map(CategoryDto.Response::from)
                .toList();
    }

    /**
     * 카테고리 + 자식들까지 한 번에 조회 (트리 구조)
     */
    public CategoryDto.ResponseWithChildren getCategoryWithChildren(Long id) {
        Category category = categoryRepository.findByIdWithChildren(id)
                .orElseThrow(() -> new IllegalArgumentException("카테고리를 찾을 수 없습니다. id=" + id));

        return CategoryDto.ResponseWithChildren.from(category);
    }
}
