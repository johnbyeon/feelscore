package com.feelscore.back.controller;

import com.feelscore.back.dto.PostEmotionDto;
import com.feelscore.back.entity.Post; // Post 엔티티는 다른 서비스에서 조회한다고 가정
import com.feelscore.back.entity.PostEmotion;
import com.feelscore.back.repository.PostRepository;
import com.feelscore.back.service.PostEmotionService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController // REST API 컨트롤러
@RequestMapping("/api/v1/emotions") // 기본 경로 설정
@RequiredArgsConstructor
public class PostEmotionController {

    private final PostEmotionService postEmotionService;
    // private final PostService postService; // Post 객체 조회를 위한 서비스라고 가정
    private final PostRepository postRepository; // ⬅️ 추가: 진짜 게시글 조회를 위해

    // --- 1. AI 분석 결과 수신 엔드포인트 (최초 생성 및 통계 반영) ---

    /**
     * 외부 AI 분석 시스템이 감정 분석 결과를 완료한 후, 우리 서버로 결과를 전달하는 콜백 엔드포인트입니다.
     * @param response AI 서버로부터 받은 분석 결과 (점수, 우세 감정 등)
     */
    @PostMapping("/callback")
    public ResponseEntity<String> receiveAnalysisResult(@RequestBody PostEmotionDto.AnalysisResponse response) {

        // 1. Post 엔티티 조회 (AI 응답의 postId를 사용)
        // 🚨 실제 구현에서는 PostService.findById(response.getPostId())를 사용해야 합니다.
        // 여기서는 임시 Post 객체를 생성하여 Service 메서드의 시그니처를 맞춥니다.
        Post post = postRepository.findById(response.getPostId())
                .orElseThrow(() -> new IllegalArgumentException("게시글이 없습니다. ID: " + response.getPostId()));

        try {
            // 이제 post 안에는 category 정보가 들어있습니다.
            postEmotionService.saveAndApplyAnalysis(
                    post,
                    response.toEntity(post).getScores(),
                    response.getDominantEmotion()
            );

            return ResponseEntity.ok("통계 반영 성공!");

        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.status(500).body("에러 발생: " + e.getMessage());
        }
    }

    // --- 2. 게시글 감정 재분석 요청 엔드포인트 (수정 및 통계 갱신) ---

    /**
     * 감정 분석 결과를 수동 또는 자동 재분석하여 갱신하고, 통계도 업데이트합니다.
     * @param postId 재분석 대상 게시글 ID
     * @param request 새로운 분석 결과 (AnalysisResponse DTO 재활용 가능)
     */
    @PutMapping("/posts/{postId}")
    public ResponseEntity<PostEmotionDto.Response> reAnalyzeEmotion(
            @PathVariable Long postId,
            @RequestBody PostEmotionDto.AnalysisResponse request) {

        // DTO -> EmotionScores 변환 로직을 활용
        PostEmotion updatedEmotion = postEmotionService.reAnalyzeAndApplyStats(
                postId,
                request.toEntity(new Post(postId)).getScores(), // Post 객체는 서비스 내부에서 조회되므로 null 전달 (scores만 필요)
                request.getDominantEmotion()
        );

        // 갱신된 엔티티를 Response DTO로 변환하여 반환
        return ResponseEntity.ok(PostEmotionDto.Response.from(updatedEmotion));
    }

    // --- 3. 특정 게시글의 감정 분석 결과 조회 ---

    /**
     * 특정 게시글 ID에 대한 감정 분석 결과를 조회합니다.
     * @param postId 조회 대상 게시글 ID
     */
    @GetMapping("/posts/{postId}")
    public ResponseEntity<PostEmotionDto.Response> getEmotionAnalysis(@PathVariable Long postId) {

        // 🚨 PostEmotionService에 조회 메서드가 있다고 가정
        PostEmotion postEmotion = postEmotionService.getEmotionAnalysisByPostId(postId);

        // DTO로 변환하여 반환
        return ResponseEntity.ok(PostEmotionDto.Response.from(postEmotion));
    }
    // ... (기존 메서드들 아래에 추가)

    // --- 4. 게시글 감정 분석 결과 삭제 및 통계 되돌리기 (테스트 및 개별 삭제용) ---

    @DeleteMapping("/posts/{postId}")
    public ResponseEntity<String> deleteEmotionAnalysis(@PathVariable Long postId) {

        try {
            // 서비스의 삭제 및 통계 차감 로직 호출
            postEmotionService.deleteAnalysisAndRevertStats(postId);

            return ResponseEntity.ok("감정 분석 데이터 삭제 및 통계 차감 완료.");

        } catch (IllegalArgumentException e) {
            // 게시글 분석 데이터가 이미 없을 때
            return ResponseEntity.status(404).body("삭제 실패: " + e.getMessage());
        } catch (Exception e) {
            return ResponseEntity.status(500).body("서버 오류: " + e.getMessage());
        }
    }


    // --- (삭제 엔드포인트는 PostController의 deletePost와 연결되어야 함) ---
}