package com.feelscore.back.controller;

import com.feelscore.back.service.S3AdminService; // S3AdminService 임포트 추가
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize; // @PreAuthorize 어노테이션을 위해 추가
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * @brief 관리자용 S3 관련 REST API 컨트롤러.
 *        관리자 웹 클라이언트의 요청을 받아 S3AdminService를 통해 S3 작업을 수행합니다.
 *        모든 요청은 백엔드에서 처리되며, 관리자 클라이언트는 S3 권한이 필요 없습니다.
 */
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/s3/admin")
public class AdminS3Controller {

    private final S3AdminService s3AdminService; // S3AdminService 주입으로 변경

    /**
     * @brief S3 버킷의 모든 파일 목록을 조회합니다.
     *        이 엔드포인트는 'ROLE_ADMIN' 권한이 있는 사용자만 접근 가능해야 합니다.
     * @return 파일 경로(objectKey) 목록
     */
    @PreAuthorize("hasRole('ADMIN')") // 'ADMIN' 역할을 가진 사용자만 접근 허용
    @GetMapping("/files")
    public ResponseEntity<List<String>> listFiles() {
        return ResponseEntity.ok(s3AdminService.listAllObjects()); // S3AdminService의 listAllObjects 호출
    }

    /**
     * @brief S3 버킷에서 특정 파일을 삭제합니다.
     *        이 엔드포인트는 'ROLE_ADMIN' 권한이 있는 사용자만 접근 가능해야 합니다.
     * @param objectKey 삭제할 S3 객체 키
     * @return 삭제 성공 메시지
     */
    @PreAuthorize("hasRole('ADMIN')") // 'ADMIN' 역할을 가진 사용자만 접근 허용
    @DeleteMapping("/delete")
    public ResponseEntity<String> deleteFile(@RequestParam String objectKey) { // 파라미터 이름을 fileName에서 objectKey로 변경
        s3AdminService.deleteObject(objectKey); // S3AdminService의 deleteObject 호출
        return ResponseEntity.ok("File deleted successfully: " + objectKey);
    }
}
