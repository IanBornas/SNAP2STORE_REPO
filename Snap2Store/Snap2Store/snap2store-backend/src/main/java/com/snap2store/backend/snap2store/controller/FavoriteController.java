package com.snap2store.backend.snap2store.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import com.snap2store.backend.snap2store.model.Favorite;
import com.snap2store.backend.snap2store.repository.FavoriteRepository;

import java.util.List;

@RestController
@RequestMapping("/api/favorites")
public class FavoriteController {

    @Autowired
    private FavoriteRepository favoriteRepository;

    // GET favorites by user
    @GetMapping("/user/{userId}")
    public List<Favorite> getFavoritesByUser(@PathVariable Long userId) {
        return favoriteRepository.findByUserId(userId);

    }

    // POST - add favorite
    @PostMapping
    public Favorite addFavorite(@RequestBody Favorite favorite) {
        return favoriteRepository.save(favorite);
    }

    // DELETE - remove favorite
    @DeleteMapping("/{id}")
    public String deleteFavorite(@PathVariable Long id) {
        favoriteRepository.deleteById(id);
        return "Favorite removed.";
    }
}
