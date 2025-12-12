package com.feelscore.back.controller;

import com.feelscore.back.dto.DmMessageResponse;
import com.feelscore.back.dto.DmSendMessageRequest;
import com.feelscore.back.entity.DmMessage;
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
    private final org.springframework.messaging.simp.SimpMessagingTemplate messagingTemplate;

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

        DmMessageResponse response = new DmMessageResponse(message, userDetails.getUserId());

        // WebSocket 구독자들에게 브로드캐스트
        messagingTemplate.convertAndSend(
                "/sub/chat/room/" + message.getThread().getId(),
                response);

        return ResponseEntity.ok(response);
    }

    // 2. 내 일반 DM함 조회
    @GetMapping("/inbox")
    public ResponseEntity<List<com.feelscore.back.dto.DmThreadMemberResponseDto>> getInbox(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        List<com.feelscore.back.dto.DmThreadMemberResponseDto> dtos = dmService.getInbox(userDetails.getUserId());
        return ResponseEntity.ok(dtos);
    }

    // 3. 내 메시지 요청함 조회
    @GetMapping("/requests")
    public ResponseEntity<List<com.feelscore.back.dto.DmThreadMemberResponseDto>> getRequestBox(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        List<com.feelscore.back.dto.DmThreadMemberResponseDto> dtos = dmService.getRequestBox(userDetails.getUserId());
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
            @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {

        // TODO: 보안상 이 유저가 이 쓰레드에 속해있는지 체크하는 로직이 Service나 여기서 필요할 수 있음.
        // -> Service에서 체크하도록 변경됨.

        Page<DmMessage> messages = dmService.loadMessages(threadId, pageable, userDetails.getUserId());

        Page<DmMessageResponse> dtos = messages.map(msg -> new DmMessageResponse(msg, userDetails.getUserId()));

        return ResponseEntity.ok(dtos);
    }

    // 9. 메시지 읽음 처리
    @PostMapping("/threads/{threadId}/read")
    public ResponseEntity<Void> markAsRead(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long threadId) {
        dmService.markAsRead(userDetails.getUserId(), threadId);
        return ResponseEntity.ok().build();
    }
}
