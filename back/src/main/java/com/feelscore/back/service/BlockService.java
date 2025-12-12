package com.feelscore.back.service;

import com.feelscore.back.entity.Block;
import com.feelscore.back.entity.Users;
import com.feelscore.back.repository.BlockRepository;
import com.feelscore.back.repository.UserRepository;
import com.feelscore.back.dto.BlockDto;
import lombok.Builder;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.NoSuchElementException;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class BlockService {

        private final BlockRepository blockRepository;
        private final UserRepository userRepository;

        /**
         * 유저 차단하기
         * - 이미 차단한 경우 예외 발생
         * - 자기 자신 차단 불가
         */
        @Transactional
        public void blockUser(Long blockerId, Long blockedId) {
                if (blockerId.equals(blockedId)) {
                        throw new IllegalArgumentException("자기 자신을 차단할 수 없습니다.");
                }

                Users blocker = userRepository.findById(blockerId)
                                .orElseThrow(() -> new NoSuchElementException("User not found: " + blockerId));
                Users blocked = userRepository.findById(blockedId)
                                .orElseThrow(() -> new NoSuchElementException("User not found: " + blockedId));

                if (blockRepository.existsByBlockerAndBlocked(blocker, blocked)) {
                        throw new IllegalStateException("이미 차단한 유저입니다.");
                }

                Block block = Block.builder()
                                .blocker(blocker)
                                .blocked(blocked)
                                .build();

                blockRepository.save(block);
        }

        /**
         * 차단 해제하기
         */
        @Transactional
        public void unblockUser(Long blockerId, Long blockedId) {
                Users blocker = userRepository.findById(blockerId)
                                .orElseThrow(() -> new NoSuchElementException("User not found: " + blockerId));
                Users blocked = userRepository.findById(blockedId)
                                .orElseThrow(() -> new NoSuchElementException("User not found: " + blockedId));

                blockRepository.deleteByBlockerAndBlocked(blocker, blocked);
        }

        /**
         * 차단 목록 조회
         */
        public List<BlockDto> getBlockList(Long userId) {
                Users blocker = userRepository.findById(userId)
                                .orElseThrow(() -> new NoSuchElementException("User not found: " + userId));

                return blockRepository.findByBlocker(blocker).stream()
                                .map(block -> BlockDto.from(block.getBlocked()))
                                .collect(Collectors.toList());
        }

        @Transactional
        public void deleteAllBlocksByUser(Long userId) {
                Users user = userRepository.findById(userId).orElseThrow();
                blockRepository.deleteByBlocker(user);
                blockRepository.deleteByBlocked(user);
        }

}
