package com.feelscore.back.repository;

import com.feelscore.back.entity.Block;
import com.feelscore.back.entity.Users;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface BlockRepository extends JpaRepository<Block, Long> {

    // 특정 유저가 다른 유저를 차단했는지 확인
    boolean existsByBlockerAndBlocked(Users blocker, Users blocked);

    // 차단 관계 삭제 (차단 해제)
    void deleteByBlockerAndBlocked(Users blocker, Users blocked);

    // 내가 차단한 목록 조회
    // 내가 차단한 목록 조회
    List<Block> findByBlocker(Users blocker);

    void deleteByBlocker(Users blocker);

    void deleteByBlocked(Users blocked);
}
