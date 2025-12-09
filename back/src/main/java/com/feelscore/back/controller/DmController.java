package com.feelscore.back.controller;

import com.feelscore.back.dto.DmMessageResponse;
import com.feelscore.back.dto.DmSendMessageRequest;
import com.feelscore.back.dto.DmThreadSummaryResponse;
import com.feelscore.back.entity.DmMessage;
import com.feelscore.back.entity.DmThreadMember;
import com.feelscore.back.security.CustomUserDetails;
import com.feelscore.back.service.DmService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/dm")
@RequiredArgsConstructor
public class DmController {

    private final DmService dmService;

    // 1. 메시지 보내기
    @PostMapping("/message")
    public ResponseEntity<DmMessageResponse> sendMessage(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @jakarta.validation.Valid @RequestBody DmSendMessageRequest request) {
        DmMessage message = dmService.sendMessage(
                userDetails.getUserId(),
                request.getReceiverId(),
                request.getThreadId(),
                request.getContent());
        return ResponseEntity.ok(new DmMessageResponse(message, userDetails.getUserId()));
    }

    // 2. 내 일반 DM함 조회
    @GetMapping("/inbox")
    public ResponseEntity<List<DmThreadSummaryResponse>> getInbox(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        List<DmThreadMember> inbox = dmService.getInbox(userDetails.getUserId());
        List<DmThreadSummaryResponse> dtos = inbox.stream()
                .map(DmThreadSummaryResponse::new)
                .toList();
        return ResponseEntity.ok(dtos);
    }

    // 3. 내 메시지 요청함 조회
    @GetMapping("/requests")
    public ResponseEntity<List<DmThreadSummaryResponse>> getRequestBox(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        List<DmThreadMember> requests = dmService.getRequestBox(userDetails.getUserId());
        List<DmThreadSummaryResponse> dtos = requests.stream()
                .map(DmThreadSummaryResponse::new)
                .toList();
        return ResponseEntity.ok(dtos);
    }

    // 4. 요청 수락
    @PostMapping("/requests/{threadId}/accept")
    public ResponseEntity<Void> acceptRequest(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long threadId) {
        dmService.acceptRequest(userDetails.getUserId(), threadId);
        return ResponseEntity.ok().build();
    }

    // 5. 요청 삭제 (거절/숨김)
    @DeleteMapping("/requests/{threadId}")
    public ResponseEntity<Void> deleteRequest(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long threadId) {
        dmService.deleteRequest(userDetails.getUserId(), threadId);
        return ResponseEntity.ok().build();
    }

    // 6. 쓰레드 숨기기 (내 화면에서 잠시 안보이게)
    @PostMapping("/threads/{threadId}/hide")
    public ResponseEntity<Void> hideThread(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long threadId) {
        dmService.hideThread(userDetails.getUserId(), threadId);
        return ResponseEntity.ok().build();
    }

    // 8. 쓰레드 나가기 (아예 삭제)
    @DeleteMapping("/threads/{threadId}/leave")
    public ResponseEntity<Void> leaveThread(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long threadId) {
        dmService.leaveThread(userDetails.getUserId(), threadId);
        return ResponseEntity.ok().build();
    }

    // 7. 메시지 목록 조회 (페이징 적용)
    @GetMapping("/threads/{threadId}/messages")
    public ResponseEntity<Page<DmMessageResponse>> getMessages(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long threadId,
            @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.ASC) Pageable pageable) {

        // TODO: 보안상 이 유저가 이 쓰레드에 속해있는지 체크하는 로직이 Service나 여기서 필요할 수 있음.
        // -> Service에서 체크하도록 변경됨.

        Page<DmMessage> messages = dmService.loadMessages(threadId, pageable, userDetails.getUserId());

        Page<DmMessageResponse> dtos = messages.map(msg -> new DmMessageResponse(msg, userDetails.getUserId()));

        return ResponseEntity.ok(dtos);
    }
}
