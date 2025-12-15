package com.feelscore.back.repository;

import com.feelscore.back.entity.Category;
import com.feelscore.back.entity.CategoryHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.Optional;

@Repository
public interface CategoryHistoryRepository extends JpaRepository<CategoryHistory, Long> {

    // Find the latest history before a certain time for a category
    Optional<CategoryHistory> findFirstByCategoryAndCreatedAtBeforeOrderByCreatedAtDesc(
            Category category, LocalDateTime time);

    // Or just find top 1 by category desc to get the VERY latest snapshot if needed
    Optional<CategoryHistory> findTopByCategoryOrderByCreatedAtDesc(Category category);
}
