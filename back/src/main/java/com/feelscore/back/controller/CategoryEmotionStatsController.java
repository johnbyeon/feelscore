package com.feelscore.back.controller;

import com.feelscore.back.dto.CategoryEmotionStatsDto;
import com.feelscore.back.service.CategoryEmotionStatsService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController // ⬅️ 이 클래스를 REST API 컨트롤러로 선언
@RequestMapping("/api/v1/stats") // ⬅️ 기본 URL 경로 설정
@RequiredArgsConstructor
public class CategoryEmotionStatsController {

    private final CategoryEmotionStatsService statsService;

    // --- 1. 전체 감정 순위 조회 (글 개수 기준) ---

    @GetMapping("/global/count")
    public ResponseEntity<List<CategoryEmotionStatsDto.GlobalRankingResponse>> getGlobalRankingByCount() {

        // 서비스 호출: 통계 조회 및 DTO 변환을 서비스가 처리합니다.
        List<CategoryEmotionStatsDto.GlobalRankingResponse> rankings =
                statsService.getGlobalEmotionRankingByCount();

        return ResponseEntity.ok(rankings); // 200 OK와 함께 DTO 목록 반환
    }

    // --- 2. 전체 감정 순위 조회 (총 점수 기준) ---

    @GetMapping("/global/score")
    public ResponseEntity<List<CategoryEmotionStatsDto.GlobalRankingResponse>> getGlobalRankingByScore() {

        // 서비스 호출
        List<CategoryEmotionStatsDto.GlobalRankingResponse> rankings =
                statsService.getGlobalEmotionRankingByScore();

        return ResponseEntity.ok(rankings); // 200 OK와 함께 DTO 목록 반환
    }

    // --- 3. 특정 카테고리 내 감정 순위 조회 ---

    @GetMapping("/categories/{categoryId}/ranking")
    public ResponseEntity<CategoryEmotionStatsDto.RankingResponse> getCategoryRanking(
            @PathVariable Long categoryId) { // ⬅️ URL 경로에서 categoryId를 추출

        // 서비스 호출
        CategoryEmotionStatsDto.RankingResponse rankingResponse =
                statsService.getCategoryEmotionRanking(categoryId);

        return ResponseEntity.ok(rankingResponse); // 200 OK와 함께 상세 랭킹 DTO 반환
    }

    // --- (이 외 다른 통계 조회 엔드포인트들을 추가할 수 있습니다.) ---
}