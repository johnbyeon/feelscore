package com.feelscore.back.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.ArrayList;
import java.util.List;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "category")
public class Category {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "category_id")
    private Long id;

    private String name; // 카테고리명 (직장, 연애 등)

    private Integer depth; // 1: 대분류, 2: 소분류

    // 부모 카테고리 (대분류)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parent_id")
    private Category parent;

    // 자식 카테고리들 (소분류 리스트)
    @OneToMany(mappedBy = "parent")
    private List<Category> children = new ArrayList<>();

    @ManyToMany(mappedBy = "categories")
    private List<CategoryVersion> versions = new ArrayList<>();

    @Builder
    public Category(String name, Integer depth, Category parent) {
        this.name = name;
        this.depth = depth;
        this.parent = parent;
        this.children = new ArrayList<>();
    }
}