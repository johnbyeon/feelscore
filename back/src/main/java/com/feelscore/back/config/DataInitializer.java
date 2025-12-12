package com.feelscore.back.config;

import com.feelscore.back.entity.*;
import com.feelscore.back.repository.CategoryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.Arrays;
import java.util.List;

@Component
@RequiredArgsConstructor
public class DataInitializer implements CommandLineRunner {

    private final CategoryRepository categoryRepository;
    private final com.feelscore.back.service.CategoryVersionService categoryVersionService;
    private final com.feelscore.back.repository.UserRepository userRepository;
    private final com.feelscore.back.repository.PostRepository postRepository;
    private final org.springframework.security.crypto.password.PasswordEncoder passwordEncoder;

    @Override
    @Transactional
    public void run(String... args) throws Exception {
        if (categoryRepository.count() == 0) {
            initializeCategories();
            categoryVersionService.createVersion("Initial Default Categories");
            System.out.println("✅ Initial Category Version 1 created.");
        }
    }

    private void initializeCategories() {
        // 대분류 리스트
        List<String> mainCategories = Arrays.asList("사회", "정치", "경제", "문화/예술", "생활/건강", "IT/과학");

        for (String mainName : mainCategories) {
            Category mainCategory = Category.builder()
                    .name(mainName)
                    .depth(1)
                    .parent(null)
                    .build();
            categoryRepository.save(mainCategory);

            // 각 대분류별 세부 소분류 (키워드)
            List<String> subCategories;
            if (mainName.equals("사회")) {
                subCategories = Arrays.asList(
                        "사건/사고", "인권/복지", "환경/기후", "교육/학교", "노동/일자리", "의료/건강", "주거/부동산", "교통/안전");
            } else if (mainName.equals("정치")) {
                subCategories = Arrays.asList(
                        "대통령/행정", "국회/정당", "선거/투표", "외교/안보", "사법/검찰", "지방자치", "국제정세", "정책/법안");
            } else if (mainName.equals("경제")) {
                subCategories = Arrays.asList(
                        "주식/투자", "부동산", "금융/재테크", "기업/산업", "창업", "취업", "물가/경제지표", "가상화폐", "세금/정책");
            } else if (mainName.equals("문화/예술")) {
                subCategories = Arrays.asList(
                        "영화/드라마", "음악/공연", "도서/문학", "전시/미술", "방송/연예", "게임", "웹툰/만화", "여행/레저", "패션/뷰티");
            } else if (mainName.equals("생활/건강")) {
                subCategories = Arrays.asList(
                        "건강/운동", "음식/맛집", "육아", "결혼/연애", "반려동물", "자동차/교통", "리빙/인테리어", "심리/멘탈케어", "쇼핑/트렌드");
            } else if (mainName.equals("IT/과학")) {
                subCategories = Arrays.asList(
                        "AI/로봇", "모바일/통신", "컴퓨터/인터넷", "반도체/하드웨어", "과학/우주", "바이오/헬스", "보안/해킹", "스타트업/테크");
            } else {
                subCategories = Arrays.asList("일반", "이슈", "트렌드");
            }

            for (String subName : subCategories) {
                Category subCategory = Category.builder()
                        .name(subName)
                        .depth(2)
                        .parent(mainCategory)
                        .build();
                categoryRepository.save(subCategory);
            }
        }

        System.out.println("✅ Dummy categories initialized (Expanded Korean Version).");

        initializeTestUsersAndPost();
    }

    private void initializeTestUsersAndPost() {
        // 1. 유저 A (글쓴이)
        Users writer = userRepository.findByEmail("writer@test.com")
                .orElseGet(() -> Users.builder()
                        .email("writer@test.com")
                        .nickname("Writer")
                        .role(Role.USER)
                        .build());

        // 비밀번호 & 토큰 강제 업데이트 (이미 존재하더라도 덮어쓰기)
        writer.setPassword(passwordEncoder.encode("1234"));
        // writer.updateFcmToken("TEST_TOKEN_WRITER"); // Cleanup: Remove hardcoded
        // token
        userRepository.save(writer);

        // 2. 유저 B (댓글러)
        Users commenter = userRepository.findByEmail("commenter@test.com")
                .orElseGet(() -> Users.builder()
                        .email("commenter@test.com")
                        .nickname("Commenter")
                        .role(Role.USER)
                        .build());

        // 비밀번호 강제 업데이트
        commenter.setPassword(passwordEncoder.encode("1234"));
        userRepository.save(commenter);

        // 3. 게시글 작성 (작성자: Writer)
        if (postRepository.count() == 0) {
            Category category = categoryRepository.findAll().stream().findFirst().orElseThrow();
            Post post = Post.builder()
                    .content("이것은 테스트 게시글입니다. 댓글을 달아보세요!")
                    .users(writer)
                    .category(category)
                    .build();
            postRepository.save(post);
            System.out.println("✅ Test Post initialized (ID: " + post.getId() + ")");
        }

        System.out.println("✅ Test Users initialized.");
        System.out.println("   - Writer: writer@test.com / 1234");
        System.out.println("   - Commenter: commenter@test.com / 1234");
    }
}
