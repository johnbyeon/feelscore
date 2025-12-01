package com.feelscore.back.exception;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor // Lombok 기본 생성자
@AllArgsConstructor // Lombok 모든 필드를 받는 생성자
public class ErrorResponse {
    private int status; // HTTP 상태 코드 (예: 404, 500)
    private String code; // 내부 오류 코드 (예: NOT_FOUND, INTERNAL_SERVER_ERROR)
    private String message; // 사용자에게 표시할 오류 메시지

    /**
     * ErrorResponse 객체를 생성하는 정적 팩토리 메서드입니다.
     * GlobalExceptionHandler에서 사용됩니다.
     */
    public static ErrorResponse of(int status, String code, String message) {
        return new ErrorResponse(status, code, message);
    }
}