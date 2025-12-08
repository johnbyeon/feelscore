package com.feelscore.back.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Table(name = "block", uniqueConstraints = {
        @UniqueConstraint(name = "uk_block_blocker_blocked", columnNames = { "blocker_id", "blocked_id" })
})
public class Block extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "block_id")
    private Long id;

    // 차단을 한 유저
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "blocker_id", nullable = false)
    private Users blocker;

    // 차단을 당한 유저
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "blocked_id", nullable = false)
    private Users blocked;

    @Builder
    public Block(Users blocker, Users blocked) {
        this.blocker = blocker;
        this.blocked = blocked;
    }
}
