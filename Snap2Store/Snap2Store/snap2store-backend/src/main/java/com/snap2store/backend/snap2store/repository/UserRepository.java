package com.snap2store.backend.snap2store.repository;

import com.snap2store.backend.snap2store.model.Users;
import org.springframework.data.jpa.repository.JpaRepository;


public interface UserRepository extends JpaRepository <Users, Long> {
    Users findByEmail(String email);
}
