package com.feelscore.back.repository;

import com.feelscore.back.entity.UserEmotion;
import com.feelscore.back.entity.Users;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface UserEmotionRepository extends JpaRepository<UserEmotion, Long> {

    Optional<UserEmotion> findByUsersAndDate(Users users, LocalDate date);

    @Query("SELECT ue FROM UserEmotion ue JOIN FETCH ue.users WHERE ue.users IN :users AND ue.date = :date")
    List<UserEmotion> findAllByUsersInAndDate(@Param("users") List<Users> users, @Param("date") LocalDate date);

    List<UserEmotion> findAllByUsersAndDateBetween(Users users, LocalDate startDate, LocalDate endDate);
}
