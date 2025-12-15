package com.feelscore.back.repository;

import com.feelscore.back.entity.Follow;
import com.feelscore.back.entity.Users;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface FollowRepository extends JpaRepository<Follow, Long> {

    boolean existsByFollowerAndFollowing(Users follower, Users following);

    void deleteByFollowerAndFollowing(Users follower, Users following);

    // 팔로워 목록 조회 (나를 팔로우 하는 사람들)
    List<Follow> findByFollowing(Users following);

    // 팔로잉 목록 조회 (내가 팔로우 하는 사람들)
    List<Follow> findByFollower(Users follower);

    long countByFollower(Users follower);

    long countByFollowing(Users following);

    void deleteByFollower(Users follower);

    void deleteByFollowing(Users following);

    // Search Followers by nickname (Case Insensitive)
    List<Follow> findByFollowingAndFollower_NicknameContainingIgnoreCase(Users following, String nickname);

    // Search Followings by nickname (Case Insensitive)
    List<Follow> findByFollowerAndFollowing_NicknameContainingIgnoreCase(Users follower, String nickname);
}
