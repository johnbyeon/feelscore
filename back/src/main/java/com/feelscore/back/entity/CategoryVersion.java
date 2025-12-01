package com.feelscore.back.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@EntityListeners(AuditingEntityListener.class)
@Table(name = "category_version")
public class CategoryVersion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "category_version_id")
    private Long id;

    @Column(nullable = false)
    private Long version;

    private String description;

    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @ManyToMany
    @JoinTable(name = "category_version_mapping", joinColumns = @JoinColumn(name = "category_version_id"), inverseJoinColumns = @JoinColumn(name = "category_id"))
    private List<Category> categories = new ArrayList<>();

    @Builder
    public CategoryVersion(Long version, String description, List<Category> categories) {
        this.version = version;
        this.description = description;
        this.categories = categories != null ? categories : new ArrayList<>();
    }
}
