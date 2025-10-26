package com.snap2store.backend.snap2store.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import com.snap2store.backend.snap2store.model.Users;
import com.snap2store.backend.snap2store.repository.UserRepository;

import java.util.List;

@RestController
@RequestMapping("/api/users")
public class UserController {

    @Autowired
    private UserRepository userRepository;

    // GET all users
    @GetMapping
    public List<Users> getAllUsers() {
        return userRepository.findAll();
    }

    // GET user by ID
    @GetMapping("/{id}")
    public Users getUserById(@PathVariable Long id) {
        return userRepository.findById(id).orElseThrow(
                () -> new RuntimeException("User not found with ID: " + id)
        );
    }

    // POST - create new user (signup)
    @PostMapping("/register")
    public Users createUser(@RequestBody Users user) {
        return userRepository.save(user);
    }

    // PUT - update user info
    @PutMapping("/{id}")
    public Users updateUser(@PathVariable Long id, @RequestBody Users updatedUser) {
        Users user = userRepository.findById(id).orElseThrow();
        user.setUsername(updatedUser.getUsername());
        user.setEmail(updatedUser.getEmail());
        user.setPassword(updatedUser.getPassword());
        return userRepository.save(user);
    }

    // DELETE - delete a user
    @DeleteMapping("/{id}")
    public String deleteUser(@PathVariable Long id) {
        userRepository.deleteById(id);
        return "User deleted with ID: " + id;
    }
}
