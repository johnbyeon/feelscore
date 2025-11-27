package com.feelscore.back.repository;

import com.feelscore.back.entity.Category;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CategoryRepository extends JpaRepository<Category, Long> {

    // 대분류 카테고리 전체 조회 (depth = 1)
    List<Category> findByDepth(Integer depth);

    // 특정 부모의 자식 카테고리 조회 (소분류)
    List<Category> findByParent_Id(Long parentId);

    // 대분류만 조회 (parent가 null)
    List<Category> findByParentIsNull();

    // 카테고리명으로 조회
    Optional<Category> findByName(String name);

    // 특정 부모 아래 특정 이름의 카테고리 조회
    Optional<Category> findByParent_IdAndName(Long parentId, String name);

    // 자식 카테고리 포함하여 조회 (Fetch Join)
    @Query("SELECT c FROM Category c LEFT JOIN FETCH c.children WHERE c.id = :id")
    Optional<Category> findByIdWithChildren(@Param("id") Long id);
}