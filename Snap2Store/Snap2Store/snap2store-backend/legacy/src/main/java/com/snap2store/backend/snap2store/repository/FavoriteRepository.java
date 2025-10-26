package com.snap2store.backend.snap2store.repository;

import com.snap2store.backend.snap2store.model.Favorite;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface FavoriteRepository extends JpaRepository <Favorite, Long> {
    List<Favorite> findByUserId(Long userId);
}
