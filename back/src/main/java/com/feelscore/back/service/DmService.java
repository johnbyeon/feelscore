package com.feelscore.back.service;

import com.feelscore.back.entity.DmFolder;
import com.feelscore.back.entity.DmMemberState;
import com.feelscore.back.entity.DmMessage;
import com.feelscore.back.entity.DmThread;
import com.feelscore.back.entity.DmThreadMember;
import com.feelscore.back.entity.Users;
import com.feelscore.back.repository.BlockRepository;
import com.feelscore.back.repository.DmMessageRepository;
import com.feelscore.back.repository.DmThreadMemberRepository;
import com.feelscore.back.repository.DmThreadRepository;
import com.feelscore.back.repository.FollowRepository;
import com.feelscore.back.repository.UserRepository;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional
public class DmService {

    private final DmThreadRepository dmThreadRepository;
    private final DmThreadMemberRepository dmThreadMemberRepository;
    private final DmMessageRepository dmMessageRepository;
    private final FollowRepository followRepository;
    private final UserRepository userRepository;
    private final BlockRepository blockRepository;
    private final NotificationService notificationService;

    /**
     * DM 메시지 보내기
     * - threadId 있으면 해당 쓰레드에 전송
     * - threadId 없으면 sender/receiver 사이의 1:1 쓰레드 찾거나 생성
     * - 팔로우 여부에 따라 NORMAL / REQUEST / PRIMARY / REQUEST 폴더 결정
     */
    public DmMessage sendMessage(Long senderId, Long receiverId, Long threadId, String content) {

        if (senderId.equals(receiverId)) {
            throw new IllegalArgumentException("자기 자신에게 DM을 보낼 수 없습니다.");
        }

        // 발신자 조회
        Users sender = findUser(senderId);

        // 수신자 미리 조회 (변수 재활용을 위해)
        Users receiver = null;
        if (receiverId != null) {
            receiver = findUser(receiverId);

            // 차단 여부 확인 (원래대로 IllegalStateException 사용)
            if (blockRepository.existsByBlockerAndBlocked(receiver, sender)) {
                throw new IllegalStateException("상대방이 당신을 차단하여 메시지를 보낼 수 없습니다.");
            }
        }

        DmThread thread;

        if (threadId != null) {
            // 1) 기존 thread 사용
            thread = dmThreadRepository.findById(threadId)
                    .orElseThrow(() -> new EntityNotFoundException("존재하지 않는 쓰레드입니다."));

            // 2) 발신자가 이 thread의 멤버인지 권한 체크
            boolean isMember = dmThreadMemberRepository.existsByThreadIdAndUserId(threadId, senderId);
            if (!isMember) {
                throw new IllegalArgumentException("해당 대화방에 접근 권한이 없습니다.");
            }

        } else {
            // threadId가 없으면 receiverId로 1:1 쓰레드 찾거나 생성
            if (receiverId == null || receiver == null) {
                throw new IllegalArgumentException("receiverId 또는 threadId 중 하나는 필수입니다.");
            }

            // 1) 기존 쓰레드 있는지 먼저 확인
            thread = dmThreadRepository
                    .findDirectThreadBetween(senderId, receiverId)
                    .orElse(null);

            if (thread == null) {
                // 2) 없으면 새 쓰레드를 만들면서 팔로우 여부로 상태/폴더 결정
                thread = createNewThread(sender, receiver);
            } else {
                // 3) 이미 존재하는 쓰레드면, 현재 팔로우 상태에 따라
                // REQUEST → PRIMARY 로 승격해줄 수 있음
                updateMemberStateByFollow(sender, receiver, thread);
            }
        }

        // 메시지 생성 및 저장
        DmMessage message = DmMessage.createText(thread, sender, content);
        dmMessageRepository.save(message);

        // 마지막 메시지 업데이트
        thread.updateLastMessage(message);

        // 보낸 사람은 읽음 처리
        DmThreadMember senderMember = dmThreadMemberRepository
                .findByThreadIdAndUserId(thread.getId(), senderId)
                .orElseThrow(() -> new EntityNotFoundException("DM 멤버 정보를 찾을 수 없습니다."));

        senderMember.updateLastRead(message);

        // 수신자에게 알림 생성 (수신자가 존재하고, 나 자신에게 보낸게 아닐 때)
        if (receiver != null && !senderId.equals(receiverId)) {

            String notiMessage = String.format("%s님이 메시지를 보냈습니다.", sender.getNickname());

            notificationService.createNotification(
                    receiver,
                    "DM",
                    notiMessage,
                    "/dm/" + thread.getId());
        }

        return message;
    }

    /**
     * ➜ 새 DM Thread 생성 (팔로우 여부에 따라 상태/폴더 자동 처리)
     */
    private DmThread createNewThread(Users sender, Users receiver) {

        DmThread thread = DmThread.create();
        dmThreadRepository.save(thread);

        // 팔로우 관계 확인
        boolean receiverFollowsSender = followRepository.existsByFollowerAndFollowing(receiver, sender);
        boolean senderFollowsReceiver = followRepository.existsByFollowerAndFollowing(sender, receiver);

        // 🔥 메시지 보낸 사람(sender) – 항상 정상 인박스
        DmMemberState senderState = DmMemberState.NORMAL;
        DmFolder senderFolder = DmFolder.PRIMARY;

        // 🔥 메시지를 받는 사람(receiver)
        // 팔로우 여부에 따라 REQUEST / NORMAL 자동 지정
        DmMemberState receiverState = (receiverFollowsSender || senderFollowsReceiver)
                ? DmMemberState.NORMAL
                : DmMemberState.REQUEST;

        DmFolder receiverFolder = (receiverState == DmMemberState.REQUEST)
                ? DmFolder.REQUEST
                : DmFolder.PRIMARY;

        // 멤버 생성
        DmThreadMember senderMember = DmThreadMember.create(thread, sender, senderState, senderFolder);
        DmThreadMember receiverMember = DmThreadMember.create(thread, receiver, receiverState, receiverFolder);

        dmThreadMemberRepository.save(senderMember);
        dmThreadMemberRepository.save(receiverMember);

        return thread;
    }

    /**
     * 기존 1:1 쓰레드가 있을 때,
     * 현재 팔로우 상태를 기반으로 REQUEST → PRIMARY 승격 처리
     */
    private void updateMemberStateByFollow(Users sender, Users receiver, DmThread thread) {

        boolean receiverFollowsSender = followRepository.existsByFollowerAndFollowing(receiver, sender);
        boolean senderFollowsReceiver = followRepository.existsByFollowerAndFollowing(sender, receiver);

        // 둘 중 하나라도 팔로우 관계가 있다면 인박스로 승격 가능
        if (receiverFollowsSender || senderFollowsReceiver) {
            DmThreadMember receiverMember = dmThreadMemberRepository
                    .findByThreadIdAndUserId(thread.getId(), receiver.getId())
                    .orElseThrow(() -> new EntityNotFoundException("DM 멤버 정보를 찾을 수 없습니다."));

            if (receiverMember.getState() == DmMemberState.REQUEST) {
                receiverMember.changeState(DmMemberState.NORMAL, DmFolder.PRIMARY);
            }
        }
    }

    /**
     * 내 일반 DM함 조회 (숨김 제외)
     */
    @Transactional(readOnly = true)
    public List<DmThreadMember> getInbox(Long userId) {
        return dmThreadMemberRepository.findByUserIdAndFolderAndHiddenFalse(userId, DmFolder.PRIMARY);
    }

    /**
     * 내 메시지 요청함 조회
     */
    @Transactional(readOnly = true)
    public List<DmThreadMember> getRequestBox(Long userId) {
        return dmThreadMemberRepository.findByUserIdAndStateAndHiddenFalse(userId, DmMemberState.REQUEST);
    }

    /**
     * DM 요청 수락 → PRIMARY + NORMAL
     */
    public void acceptRequest(Long userId, Long threadId) {

        DmThreadMember me = dmThreadMemberRepository
                .findByThreadIdAndUserId(threadId, userId)
                .orElseThrow(() -> new EntityNotFoundException("DM 멤버 정보를 찾을 수 없습니다."));

        if (me.getState() == DmMemberState.REQUEST) {
            me.changeState(DmMemberState.NORMAL, DmFolder.PRIMARY);
        }
    }

    /**
     * DM 요청 삭제 (내 화면에서만 숨김)
     */
    public void deleteRequest(Long userId, Long threadId) {

        DmThreadMember me = dmThreadMemberRepository
                .findByThreadIdAndUserId(threadId, userId)
                .orElseThrow(() -> new EntityNotFoundException("DM 멤버 정보를 찾을 수 없습니다."));

        if (me.getState() == DmMemberState.REQUEST) {
            me.changeState(DmMemberState.DELETED, DmFolder.REQUEST);
            me.hide();
        }
    }

    /**
     * DM 쓰레드를 내 화면에서 숨기기 (나가기)
     */
    public void hideThread(Long userId, Long threadId) {

        DmThreadMember me = dmThreadMemberRepository
                .findByThreadIdAndUserId(threadId, userId)
                .orElseThrow(() -> new EntityNotFoundException("DM 멤버 정보를 찾을 수 없습니다."));

        me.hide();
    }

    /**
     * DM 쓰레드 완전히 나가기 (멤버 삭제)
     */
    public void leaveThread(Long userId, Long threadId) {
        DmThreadMember me = dmThreadMemberRepository
                .findByThreadIdAndUserId(threadId, userId)
                .orElseThrow(() -> new EntityNotFoundException("DM 멤버 정보를 찾을 수 없습니다."));

        dmThreadMemberRepository.delete(me);

        // (선택사항) 쓰레드에 남은 멤버가 없으면 쓰레드 자체를 삭제하는 로직 추가 가능
        // int remaining = dmThreadMemberRepository.countByThreadId(threadId); // 예시
    }

    /**
     * 특정 쓰레드 메시지 전체 불러오기 (Legacy)
     */
    @Transactional(readOnly = true)
    public List<DmMessage> loadMessages(Long threadId) {
        return dmMessageRepository.findByThreadIdOrderByCreatedAtAsc(threadId);
    }

    /**
     * 특정 쓰레드 메시지 페이징 불러오기
     * - Pageable을 통해 offset, limit 처리
     * - 접근 권한 체크 추가
     */
    @Transactional(readOnly = true)
    public Page<DmMessage> loadMessages(Long threadId, Pageable pageable, Long userId) {
        // 권한 체크: 사용자가 해당 쓰레드의 멤버인지 확인
        boolean isMember = dmThreadMemberRepository.existsByThreadIdAndUserId(threadId, userId);
        if (!isMember) {
            throw new IllegalArgumentException("해당 대화방에 접근 권한이 없습니다.");
        }

        // TODO: 향후 퍼포먼스 이슈 시 NoOffset 방식(lastMessageId 기반) 고려 가능
        return dmMessageRepository.findByThreadIdOrderByCreatedAtAsc(threadId, pageable);
    }

    // ======================
    // 내부 메서드
    // ======================

    private Users findUser(Long id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("유저를 찾을 수 없습니다. id=" + id));
    }
}
