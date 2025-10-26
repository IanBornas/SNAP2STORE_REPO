package com.snap2store.backend.snap2store.repository;

import com.snap2store.backend.snap2store.model.Location;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface LocationRepository extends JpaRepository <Location, Long> {
    List<Location> findByVerifiedTrue();
}
