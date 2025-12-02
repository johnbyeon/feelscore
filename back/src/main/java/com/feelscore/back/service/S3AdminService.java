package com.feelscore.back.service;

import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.model.ListObjectsV2Result;
import com.amazonaws.services.s3.model.S3ObjectSummary;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

/**
 * @brief 관리자 전용 S3 서비스.
 *        관리자의 요청을 받아 백엔드(Spring Boot)가 직접 S3와 상호작용합니다.
 *        앱/웹 클라이언트는 AWS 권한 없이 백엔드 API만 호출합니다.
 */
@Service
@RequiredArgsConstructor
public class S3AdminService {

    private final AmazonS3 amazonS3;

    @Value("${spring.cloud.aws.s3.bucket}") // application.yml의 spring.cloud.aws.s3.bucket 속성 사용
    private String bucket;

    /**
     * @brief S3 버킷의 모든 객체(파일) 목록을 조회합니다.
     *        관리자용 기능으로, 모든 파일에 대한 접근 권한을 가집니다.
     * @return S3 객체 키(경로 포함 파일명) 목록
     */
    public List<String> listAllObjects() {
        ListObjectsV2Result result = amazonS3.listObjectsV2(bucket);
        List<String> objectKeys = new ArrayList<>();

        // 버킷 내 모든 객체의 요약 정보를 순회하며 객체 키(Key)를 리스트에 추가
        for (S3ObjectSummary s : result.getObjectSummaries()) {
            objectKeys.add(s.getKey());
        }
        return objectKeys;
    }

    /**
     * @brief S3 버킷에서 특정 객체(파일)를 삭제합니다.
     *        관리자용 기능으로, 특정 파일에 대한 삭제 권한을 가집니다.
     * @param objectKey 삭제할 S3 객체 키 (경로 포함 파일명)
     */
    public void deleteObject(String objectKey) {
        // S3에 deleteObject 요청을 보내어 지정된 객체를 삭제
        amazonS3.deleteObject(bucket, objectKey);
    }
}
