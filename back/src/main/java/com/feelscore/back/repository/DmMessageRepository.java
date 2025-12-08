package com.feelscore.back.repository;

import com.feelscore.back.entity.DmMessage;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface DmMessageRepository extends JpaRepository<DmMessage, Long> {

    /**
     * 한 대화방의 메시지 전체를 시간 순으로 조회
     */
    List<DmMessage> findByThreadIdOrderByCreatedAtAsc(Long threadId);
}
