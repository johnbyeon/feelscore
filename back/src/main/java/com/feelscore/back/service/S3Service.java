package com.feelscore.back.service;

import com.amazonaws.HttpMethod;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.model.*;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.URL;
import java.util.Date;
import java.util.Map;
import java.util.UUID; // 고유한 파일명 생성을 위해 추가

/**
 * @brief 일반 유저 전용 S3 서비스.
 *        유저가 직접 S3에 파일을 업로드/다운로드할 수 있도록 Presigned URL을 생성하는 기능을 제공합니다.
 *        백엔드는 유저의 요청을 받아 Presigned URL만 생성하며, 실제 파일 전송은 유저와 S3 간에 직접 이루어집니다.
 */
@Service
@RequiredArgsConstructor
public class S3Service {

    private final AmazonS3 amazonS3; // S3 클라이언트 주입

    @Value("${spring.cloud.aws.s3.bucket}") // application.yml의 spring.cloud.aws.s3.bucket 속성 사용
    private String bucket; // S3 버킷 이름 주입

    /**
     * @brief 유저가 S3에 파일을 업로드할 수 있도록 Presigned PUT URL을 생성합니다.
     *        이 URL을 통해 유저는 백엔드를 거치지 않고 S3에 직접 파일을 업로드합니다.
     *        파일은 'users/{userId}/images/{고유_파일_이름}' 경로로 저장됩니다.
     * @param userId           현재 로그인한 유저의 고유 ID
     * @param originalFileName 유저가 업로드할 파일의 원본 이름 (확장자 추출용)
     * @param contentType      업로드할 파일의 MIME 타입 (예: image/jpeg, image/png)
     * @return 생성된 Presigned PUT URL 및 S3 객체 키를 포함하는 Map (또는 별도의 DTO)
     */
    public Map<String, String> generatePresignedPutUrl(Long userId, String originalFileName, String contentType) {
        // S3 버킷 내에 저장될 객체 키(파일 경로) 생성.
        String fileExtension = "";
        if (originalFileName != null && originalFileName.contains(".")) {
            fileExtension = originalFileName.substring(originalFileName.lastIndexOf("."));
        }
        // 공개 접근이 가능한 'public/' 폴더 하위에 저장합니다.
        String objectKey = "public/users/" + userId + "/images/" + UUID.randomUUID().toString() + fileExtension;

        // Presigned URL의 유효 시간 (현재 시간으로부터 5분 후)
        Date expiration = new Date();
        long expTimeMillis = expiration.getTime();
        expTimeMillis += 1000 * 60 * 5; // 5분
        expiration.setTime(expTimeMillis);

        // Presigned URL 생성 요청 객체 설정
        // HttpMethod.PUT: 파일 업로드용
        GeneratePresignedUrlRequest generatePresignedUrlRequest = new GeneratePresignedUrlRequest(bucket, objectKey)
                .withMethod(HttpMethod.PUT)
                .withExpiration(expiration);

        // Content-Type 헤더를 Presigned URL에 포함시켜 업로드 시 유효성 검증
        generatePresignedUrlRequest.setContentType(contentType);

        // Presigned URL 생성
        URL presignedUrl = amazonS3.generatePresignedUrl(generatePresignedUrlRequest);

        return Map.of(
                "presignedUrl", presignedUrl.toString(),
                "objectKey", objectKey // 생성된 objectKey도 함께 반환하여 클라이언트가 DB에 저장할 수 있도록 합니다.
        );
    }

    /**
     * @brief 유저가 S3에 저장된 자신의 파일을 다운로드할 수 있도록 Presigned GET URL을 생성합니다.
     *        이 URL을 통해 유저는 백엔드를 거치지 않고 S3에서 직접 파일을 다운로드합니다.
     *        요청된 objectKey가 해당 userId의 경로에 속하는지 외부에서 검증해야 합니다.
     * @param userId            현재 로그인한 유저의 고유 ID
     * @param objectKey         다운로드할 S3 객체 키 (예:
     *                          users/user123/images/unique_image_id.jpg)
     * @param expirationMinutes Presigned URL의 유효 시간 (분 단위)
     * @return 생성된 Presigned GET URL 문자열
     * @throws IllegalArgumentException 요청된 objectKey가 해당 유저의 경로에 속하지 않을 경우 발생
     */
    public String generatePresignedGetUrl(Long userId, String objectKey, long expirationMinutes) {
        // 보안 검증: 요청된 objectKey가 해당 userId의 경로에 속하는지 확인
        if (!objectKey.startsWith("users/" + userId + "/")) {
            throw new IllegalArgumentException("Unauthorized access to objectKey: " + objectKey);
        }

        // Presigned URL의 유효 시간 설정
        Date expiration = new Date();
        long expTimeMillis = expiration.getTime();
        expTimeMillis += 1000 * 60 * expirationMinutes;
        expiration.setTime(expTimeMillis);

        // Presigned URL 생성 요청 객체 설정
        // HttpMethod.GET: 파일 다운로드용
        GeneratePresignedUrlRequest generatePresignedUrlRequest = new GeneratePresignedUrlRequest(bucket, objectKey)
                .withMethod(HttpMethod.GET)
                .withExpiration(expiration);

        // Presigned URL 생성 및 반환
        return amazonS3.generatePresignedUrl(generatePresignedUrlRequest).toString();
    }

    /**
     * @brief S3 버킷에서 특정 객체(파일)를 삭제합니다.
     * @param objectKey 삭제할 S3 객체 키
     */
    public void deleteFile(String objectKey) {
        amazonS3.deleteObject(bucket, objectKey);
    }
}
