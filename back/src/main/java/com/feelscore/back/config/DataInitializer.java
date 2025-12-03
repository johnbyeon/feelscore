package com.feelscore.back.config;

import com.feelscore.back.entity.Category;
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
                        "인권", "환경", "교육", "의료", "범죄", "안전", "교통", "주거", "복지", "노동",
                        "세대갈등", "다문화", "인구", "지역", "종교", "언론", "시민단체", "봉사", "기부", "재난");
            } else if (mainName.equals("정치")) {
                subCategories = Arrays.asList(
                        "선거", "정당", "국회", "청와대", "행정", "사법", "외교", "국방", "통일", "지방자치",
                        "정책", "법안", "여론", "시위", "인물", "비리", "개혁", "국제관계", "인권", "안보");
            } else if (mainName.equals("경제")) {
                subCategories = Arrays.asList(
                        "주식", "부동산", "물가", "금리", "환율", "가상화폐", "창업", "취업", "기업", "무역",
                        "세금", "연금", "소비", "투자", "금융", "산업", "기술", "에너지", "농업", "유통");
            } else if (mainName.equals("문화/예술")) {
                subCategories = Arrays.asList(
                        "영화", "음악", "미술", "공연", "문학", "전시", "축제", "전통", "디자인", "패션",
                        "뷰티", "건축", "사진", "만화", "게임", "방송", "유튜브", "OTT", "취미", "여행");
            } else if (mainName.equals("생활/건강")) {
                subCategories = Arrays.asList(
                        "다이어트", "운동", "요리", "맛집", "육아", "반려동물", "인테리어", "자동차", "쇼핑", "심리",
                        "멘탈케어", "수면", "스트레스", "병원", "약국", "보험", "날씨", "운세", "상담", "힐링");
            } else if (mainName.equals("IT/과학")) {
                subCategories = Arrays.asList(
                        "AI", "로봇", "우주", "바이오", "반도체", "스마트폰", "인터넷", "보안", "빅데이터", "클라우드",
                        "블록체인", "메타버스", "스타트업", "코딩", "해킹", "통신", "가전", "드론", "전기차", "배터리");
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
    }
}
