package com.feelscore.back.controller;

import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.model.S3Object;
import com.amazonaws.services.s3.model.S3ObjectInputStream;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import jakarta.servlet.http.HttpServletRequest;

import java.io.IOException;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;

@RestController
@RequestMapping("/api/public")
@RequiredArgsConstructor
public class PublicS3Controller {

    private final AmazonS3 amazonS3;

    @Value("${spring.cloud.aws.s3.bucket}")
    private String bucket;

    @GetMapping("/**")
    public ResponseEntity<InputStreamResource> getPublicFile(HttpServletRequest request) throws IOException {
        // Extract path after /api/
        String requestUri = request.getRequestURI();
        // /api/public/users/1/images/foo.jpg -> public/users/1/images/foo.jpg
        // We need to match the S3 key.
        // The DB stores "public/users/1/images/foo.jpg" (based on observation)
        // The request is /api/public/users/1/images/foo.jpg
        return getFileFromS3(requestUri.substring("/api/".length()));
    }

    private ResponseEntity<InputStreamResource> getFileFromS3(String key) {
        try {
            String decodedKey = URLDecoder.decode(key, StandardCharsets.UTF_8.toString());

            S3Object s3Object = amazonS3.getObject(bucket, decodedKey);
            S3ObjectInputStream inputStream = s3Object.getObjectContent();

            MediaType mediaType = MediaType.APPLICATION_OCTET_STREAM;
            String fileName = decodedKey;

            if (decodedKey.toLowerCase().endsWith(".jpg") || decodedKey.toLowerCase().endsWith(".jpeg")) {
                mediaType = MediaType.IMAGE_JPEG;
            } else if (decodedKey.toLowerCase().endsWith(".png")) {
                mediaType = MediaType.IMAGE_PNG;
            } else if (decodedKey.toLowerCase().endsWith(".gif")) {
                mediaType = MediaType.IMAGE_GIF;
            }

            return ResponseEntity.ok()
                    .contentType(mediaType)
                    .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + fileName + "\"")
                    .body(new InputStreamResource(inputStream));
        } catch (Exception e) {
            return ResponseEntity.notFound().build();
        }
    }
}
