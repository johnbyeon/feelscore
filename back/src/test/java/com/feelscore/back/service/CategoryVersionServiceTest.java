package com.feelscore.back.service;

import com.feelscore.back.dto.CategoryDto;
import com.feelscore.back.entity.Category;
import com.feelscore.back.entity.CategoryVersion;
import com.feelscore.back.repository.CategoryRepository;
import com.feelscore.back.repository.CategoryVersionRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Arrays;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class CategoryVersionServiceTest {

    @InjectMocks
    private CategoryVersionService categoryVersionService;

    @Mock
    private CategoryVersionRepository categoryVersionRepository;

    @Mock
    private CategoryRepository categoryRepository;

    @Test
    @DisplayName("새로운 버전을 생성한다")
    void createVersion() {
        // given
        Category cat1 = Category.builder().name("Category 1").build();
        Category cat2 = Category.builder().name("Category 2").build();
        List<Category> categories = Arrays.asList(cat1, cat2);

        given(categoryRepository.findAll()).willReturn(categories);
        given(categoryVersionRepository.findMaxVersion()).willReturn(Optional.of(1L));
        given(categoryVersionRepository.save(any(CategoryVersion.class)))
                .willAnswer(invocation -> invocation.getArgument(0));

        // when
        Long version = categoryVersionService.createVersion("New Version");

        // then
        assertThat(version).isEqualTo(2L);
        verify(categoryVersionRepository).save(any(CategoryVersion.class));
    }

    @Test
    @DisplayName("특정 버전의 카테고리 목록을 조회한다")
    void getCategoriesByVersion() {
        // given
        Category cat1 = Category.builder().name("Category 1").build();
        CategoryVersion version = CategoryVersion.builder()
                .version(1L)
                .categories(List.of(cat1))
                .build();

        given(categoryVersionRepository.findAll()).willReturn(List.of(version));

        // when
        List<CategoryDto.Response> result = categoryVersionService.getCategoriesByVersion(1L);

        // then
        assertThat(result).hasSize(1);
        assertThat(result.get(0).getName()).isEqualTo("Category 1");
    }
}
