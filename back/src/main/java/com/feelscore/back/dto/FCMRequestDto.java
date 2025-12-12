package com.feelscore.back.dto;

import java.util.Map;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
public class FCMRequestDto {
    private String targetToken;
    private String title;
    private String body;
    private Map<String, String> data;
}
