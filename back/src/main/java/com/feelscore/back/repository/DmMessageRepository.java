package com.feelscore.back.repository;

import com.feelscore.back.entity.DmMessage;
import org.springframework.data.jpa.repository.JpaRepository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import java.util.List;

public interface DmMessageRepository extends JpaRepository<DmMessage, Long> {

    /**
     * 한 대화방의 메시지 전체를 시간 순으로 조회 (Legacy)
     */
    List<DmMessage> findByThreadIdOrderByCreatedAtAsc(Long threadId);

    /**
     * 한 대화방의 메시지 페이징 조회
     * - page: 요청할 페이지 번호
     * - size: 한 번에 불러올 개수
     */
    Page<DmMessage> findByThreadIdOrderByCreatedAtAsc(Long threadId, Pageable pageable);
}
