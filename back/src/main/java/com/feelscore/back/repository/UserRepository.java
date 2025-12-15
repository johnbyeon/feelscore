package com.feelscore.back.repository;

import java.util.Optional;
import java.util.List;

import com.feelscore.back.entity.Users;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserRepository extends JpaRepository<Users, Long> {

    boolean existsByEmail(String email);

    Optional<Users> findByEmail(String email);

    Optional<Users> findByNickname(String nickname);

    List<Users> findByNicknameContainingIgnoreCase(String nickname);
}
