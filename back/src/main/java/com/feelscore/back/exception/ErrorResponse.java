package com.feelscore.back.exception;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor // Lombok 기본 생성자
@AllArgsConstructor // Lombok 모든 필드를 받는 생성자
@JsonInclude(JsonInclude.Include.NON_NULL) // null인 필드(validationErrors 등)는 JSON 응답에서 제외
public class ErrorResponse {
    private int status; // HTTP 상태 코드
    private String code; // 내부 오류 코드
    private String message; // 사용자에게 표시할 오류 메시지
    private java.util.Map<String, String> validationErrors; // (Optional) 유효성 검사 실패 상세 내역

    public ErrorResponse(int status, String code, String message) {
        this.status = status;
        this.code = code;
        this.message = message;
    }

    /**
     * ErrorResponse 객체를 생성하는 정적 팩토리 메서드입니다.
     * GlobalExceptionHandler에서 사용됩니다.
     */
    /**
     * 기본 ErrorResponse 생성
     */
    public static ErrorResponse of(int status, String code, String message) {
        return new ErrorResponse(status, code, message, null);
    }

    /**
     * Validation ErrorResponse 생성 (상세 내역 포함)
     */
    public static ErrorResponse of(int status, String code, String message,
            java.util.Map<String, String> validationErrors) {
        return new ErrorResponse(status, code, message, validationErrors);
    }
}