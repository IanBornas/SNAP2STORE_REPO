package com.snap2store.backend.snap2store.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import com.snap2store.backend.snap2store.model.Post;
import com.snap2store.backend.snap2store.repository.PostRepository;

import java.util.List;

@RestController
@RequestMapping("/api/posts")
public class PostController {

    @Autowired
    private PostRepository postRepository;

    // GET all posts
    @GetMapping
    public List<Post> getAllPosts() {
        return postRepository.findAll();
    }

    // GET posts by user
    @GetMapping("/user/{userId}")
    public List<Post> getPostsByUser(@PathVariable Long userId) {
        return postRepository.FindByUserId(userId);
    }

    // POST - create new post
    @PostMapping
    public Post createPost(@RequestBody Post post) {
        return postRepository.save(post);
    }

    // PUT - update post description
    @PutMapping("/{id}")
    public Post updatePost(@PathVariable Long id, @RequestBody Post updatedPost) {
        Post post = postRepository.findById(id).orElseThrow();
        post.setDescription(updatedPost.getDescription());
        return postRepository.save(post);
    }

    // DELETE - delete a post
    @DeleteMapping("/{id}")
    public String deletePost(@PathVariable Long id) {
        postRepository.deleteById(id);
        return "Post deleted successfully.";
    }
}
