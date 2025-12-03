package com.feelscore.back.repository;

import com.feelscore.back.entity.CategoryVersion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.Optional;

public interface CategoryVersionRepository extends JpaRepository<CategoryVersion, Long> {

    @Query("SELECT MAX(cv.version) FROM CategoryVersion cv")
    Optional<Long> findMaxVersion();

    Optional<CategoryVersion> findTopByOrderByVersionDesc();
}
