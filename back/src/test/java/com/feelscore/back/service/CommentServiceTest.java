package com.feelscore.back.service;

import com.feelscore.back.entity.*;
import com.feelscore.back.repository.CommentReactionRepository;
import com.feelscore.back.repository.CommentRepository;
import com.feelscore.back.repository.PostRepository;
import com.feelscore.back.repository.UserRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class CommentServiceTest {

    @InjectMocks
    private CommentService commentService;

    @Mock
    private CommentRepository commentRepository;

    @Mock
    private CommentReactionRepository commentReactionRepository;

    @Mock
    private PostRepository postRepository;

    @Mock
    private UserRepository userRepository;

    @Test
    @DisplayName("댓글을 생성한다")
    void createComment() {
        // given
        Long postId = 1L;
        Long userId = 1L;
        String content = "Test Comment";

        Post post = new Post(postId);
        Users user = Users.builder().email("test@test.com").build();

        given(postRepository.findById(postId)).willReturn(Optional.of(post));
        given(userRepository.findById(userId)).willReturn(Optional.of(user));
        given(commentRepository.save(any(Comment.class))).willAnswer(invocation -> {
            Comment c = invocation.getArgument(0);
            return c; // Mock save behavior
        });

        // when
        // when
        commentService.createComment(postId, userId, content, null);

        // then
        verify(commentRepository).save(any(Comment.class));
    }

    @Test
    @DisplayName("댓글에 반응을 추가한다")
    void addReaction() {
        // given
        Long commentId = 1L;
        Long userId = 1L;
        EmotionType emotion = EmotionType.SADNESS;

        Comment comment = Comment.builder().content("Comment").build();
        Users user = Users.builder().email("test@test.com").build();

        given(commentRepository.findById(commentId)).willReturn(Optional.of(comment));
        given(userRepository.findById(userId)).willReturn(Optional.of(user));
        given(commentReactionRepository.findByCommentAndUsers(comment, user)).willReturn(Optional.empty());

        // when
        commentService.addReaction(commentId, userId, emotion);

        // then
        verify(commentReactionRepository).save(any(CommentReaction.class));
    }
}
