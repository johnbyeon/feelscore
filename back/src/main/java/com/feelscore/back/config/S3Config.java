package com.feelscore.back.config;

import com.amazonaws.auth.AWSStaticCredentialsProvider;
import com.amazonaws.auth.BasicAWSCredentials;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * @brief AWS S3 클라이언트 설정을 위한 Spring Configuration 클래스.
 *        application.yml에 정의된 AWS 자격 증명과 리전을 사용하여
 *        AmazonS3 클라이언트 빈을 생성합니다.
 */
@Slf4j
@Configuration
public class S3Config {

    // AWS Access Key ID 주입 (application.yml의
    // spring.cloud.aws.credentials.access-key 사용)
    @Value("${spring.cloud.aws.credentials.access-key}")
    private String accessKey;

    // AWS Secret Access Key 주입 (application.yml의
    // spring.cloud.aws.credentials.secret-key 사용)
    @Value("${spring.cloud.aws.credentials.secret-key}")
    private String secretKey;

    // AWS Region 주입 (application.yml의 spring.cloud.aws.region.static 사용)
    @Value("${spring.cloud.aws.region.static}")
    private String region;

    /**
     * @brief AmazonS3 클라이언트 빈을 생성하여 Spring 컨텍스트에 등록합니다.
     * @return 설정된 AmazonS3 클라이언트 인스턴스
     */
    @Bean
    public AmazonS3 amazonS3() {
        // 주입받은 AWS 자격 증명 값을 로그로 출력하여 확인 (디버깅용)
        log.info("S3Config: Initializing AmazonS3 client.");
        log.info("S3Config: AWS Access Key ID (first 4 chars): {}",
                accessKey != null && accessKey.length() >= 4 ? accessKey.substring(0, 4) : "N/A");
        log.info("S3Config: AWS Secret Access Key is set: {}", secretKey != null && !secretKey.isEmpty());
        log.info("S3Config: AWS Region: {}", region);

        try {
            BasicAWSCredentials creds = new BasicAWSCredentials(accessKey, secretKey);

            return AmazonS3ClientBuilder.standard()
                    .withRegion(region)
                    .withCredentials(new AWSStaticCredentialsProvider(creds))
                    .build();
        } catch (Exception e) {
            log.error("S3Config: Failed to build AmazonS3 client. Check AWS credentials and region.", e);
            throw new RuntimeException("Failed to initialize AmazonS3 client. Check AWS credentials and region.", e);
        }
    }
}
