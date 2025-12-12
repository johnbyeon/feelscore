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

    void deleteBySender(com.feelscore.back.entity.Users sender);

    List<DmMessage> findBySender(com.feelscore.back.entity.Users sender);

    /**
     * 한 대화방의 메시지 페이징 조회 (정렬 조건은 Pageable에서 정의)
     */
    Page<DmMessage> findByThreadId(Long threadId, Pageable pageable);

    /**
     * 안 읽은 메시지 개수 계산
     * - lastReadMessageId 이후의 메시지 개수
     */
    long countByThreadIdAndIdGreaterThan(Long threadId, Long lastReadMessageId);

    /**
     * 안 읽은 메시지 개수 계산 (읽은 메시지가 없을 때 - 전체 개수)
     */
    long countByThreadId(Long threadId);
}
