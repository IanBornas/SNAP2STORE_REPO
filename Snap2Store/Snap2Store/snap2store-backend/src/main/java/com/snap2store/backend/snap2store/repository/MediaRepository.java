package com.snap2store.backend.snap2store.repository;

import com.snap2store.backend.snap2store.model.Media;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface MediaRepository extends JpaRepository <Media, Long> {
    List<Media> findByType(String type);
}
