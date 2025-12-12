package com.feelscore.back.repository;

import com.feelscore.back.entity.DmThread;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface DmThreadRepository extends JpaRepository<DmThread, Long> {

    /**
     * 두 유저 사이의 1:1 DM 쓰레드를 찾는다.
     * (항상 멤버가 2명인 구조를 전제로 함)
     */
    @Query("""
            select t
            from DmThread t
                join t.members m1
                join t.members m2
            where m1.user.id = :userId1
              and m2.user.id = :userId2
            """)
    Optional<DmThread> findDirectThreadBetween(
            @Param("userId1") Long userId1,
            @Param("userId2") Long userId2);

    @org.springframework.data.jpa.repository.Modifying
    @Query("UPDATE DmThread t SET t.lastMessage = null WHERE t.lastMessage.sender = :sender")
    void setLastMessageNullBySender(@Param("sender") com.feelscore.back.entity.Users sender);
}
