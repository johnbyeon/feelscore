package com.feelscore.back.controller;

import com.feelscore.back.service.S3Service;
import com.feelscore.back.security.CustomUserDetails; // CustomUserDetails 임포트 추가
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize; // @PreAuthorize 어노테이션을 위해 추가
import org.springframework.security.core.Authentication; // Authentication 객체를 위해 추가
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * @brief 일반 유저용 S3 파일 업로드/다운로드 Presigned URL 관련 REST API 컨트롤러.
 *        로그인한 일반 유저가 S3에 직접 접근하기 위한 Presigned URL을 요청하는 엔드포인트를 제공합니다.
 *        모든 요청은 'ROLE_USER' 권한을 가진 인증된 사용자만 접근 가능합니다.
 */
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/s3/user")
public class UserUploadController {

    private final S3Service s3Service; // S3Service 주입

    /**
     * @brief 유저가 파일을 S3에 업로드하기 위한 Presigned PUT URL을 요청합니다.
     *        'ROLE_USER' 권한을 가진 인증된 사용자만 호출할 수 있습니다.
     * @param authentication 현재 로그인한 유저의 인증 정보 (Spring Security가 제공)
     * @param originalFileName 유저가 업로드할 파일의 원본 이름 (확장자 추출용)
     * @param contentType 업로드할 파일의 MIME 타입
     * @return Presigned URL과 S3에 저장될 objectKey를 포함하는 응답
     */
    @PreAuthorize("hasRole('USER')") // 'USER' 역할을 가진 사용자만 접근 허용
    @PostMapping("/upload-presigned") // 엔드포인트명 변경
    public ResponseEntity<Map<String, String>> getUploadPresignedUrl(
            Authentication authentication,
            @RequestParam String originalFileName,
            @RequestParam String contentType
    ) {
        // Authentication 객체의 principal에서 CustomUserDetails를 가져와 실제 userId를 사용합니다.
        CustomUserDetails customUserDetails = (CustomUserDetails) authentication.getPrincipal();
        Long userId = customUserDetails.getUserId(); // CustomUserDetails에서 userId 가져오기

        Map<String, String> presignedUrlInfo = s3Service.generatePresignedPutUrl(userId, originalFileName, contentType);

        return ResponseEntity.ok(presignedUrlInfo);
    }

    /**
     * @brief 유저가 S3에 저장된 자신의 파일을 다운로드하기 위한 Presigned GET URL을 요청합니다.
     *        'ROLE_USER' 권한을 가진 인증된 사용자만 호출할 수 있습니다.
     * @param authentication 현재 로그인한 유저의 인증 정보
     * @param objectKey 다운로드할 파일의 S3 객체 키 (예: users/user123/images/unique_image_id.jpg)
     * @param expirationMinutes Presigned URL의 유효 시간 (분 단위)
     * @return Presigned GET URL
     */
    @PreAuthorize("hasRole('USER')") // 'USER' 역할을 가진 사용자만 접근 허용
    @GetMapping("/download-presigned")
    public ResponseEntity<String> getDownloadPresignedUrl(
            Authentication authentication,
            @RequestParam String objectKey,
            @RequestParam(defaultValue = "5") long expirationMinutes // 기본 5분 유효
    ) {
        // Authentication 객체의 principal에서 CustomUserDetails를 가져와 실제 userId를 사용합니다.
        CustomUserDetails customUserDetails = (CustomUserDetails) authentication.getPrincipal();
        Long userId = customUserDetails.getUserId(); // CustomUserDetails에서 userId 가져오기

        try {
            String presignedUrl = s3Service.generatePresignedGetUrl(userId, objectKey, expirationMinutes);
            return ResponseEntity.ok(presignedUrl);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(403).body(e.getMessage());
        }
    }
}
