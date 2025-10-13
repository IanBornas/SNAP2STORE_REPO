package com.snap2store.backend.snap2store.repository;

import com.snap2store.backend.snap2store.model.Post;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PostRepository extends JpaRepository <Post, Long> {
    List<Post> FindByUserId(Long userId);
}
