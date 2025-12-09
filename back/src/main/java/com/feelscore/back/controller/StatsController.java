package com.feelscore.back.controller;

import com.feelscore.back.dto.CategoryStatsDto;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/stats")
@RequiredArgsConstructor
public class StatsController {

        private final com.feelscore.back.service.CategoryStatsService categoryStatsService;

        @GetMapping("/home")
        public List<CategoryStatsDto> getHomeStats(
                        @org.springframework.web.bind.annotation.RequestParam(value = "period", defaultValue = "ALL") com.feelscore.back.dto.StatsPeriod period) {
                return categoryStatsService.getRealtimeStats(period);
        }

}
