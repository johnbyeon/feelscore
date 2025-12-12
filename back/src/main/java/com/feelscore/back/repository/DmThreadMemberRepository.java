package com.feelscore.back.repository;

import com.feelscore.back.entity.DmFolder;
import com.feelscore.back.entity.DmMemberState;
import com.feelscore.back.entity.DmThreadMember;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface DmThreadMemberRepository extends JpaRepository<DmThreadMember, Long> {

    /**
     * 특정 유저가 참여 중인 모든 DM (숨김 아닌 것만)
     */
    List<DmThreadMember> findByUserIdAndHiddenFalse(Long userId);

    /**
     * 특정 유저의 폴더(예: PRIMARY / REQUEST) 기준 DM 목록
     */
    List<DmThreadMember> findByUserIdAndFolderAndHiddenFalse(Long userId, DmFolder folder);

    /**
     * 메시지 요청함만 보고 싶을 때
     */
    List<DmThreadMember> findByUserIdAndStateAndHiddenFalse(Long userId, DmMemberState state);

    /**
     * thread + user 조합으로 한 row 찾기 (상태 업데이트용)
     */
    Optional<DmThreadMember> findByThreadIdAndUserId(Long threadId, Long userId);

    /**
     * 해당 쓰레드에 유저가 참여중인지 확인 (권한 체크용)
     */
    boolean existsByThreadIdAndUserId(Long threadId, Long userId);

    void deleteByUser(com.feelscore.back.entity.Users user);
}
