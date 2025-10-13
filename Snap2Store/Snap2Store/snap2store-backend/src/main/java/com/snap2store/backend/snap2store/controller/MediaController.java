package com.snap2store.backend.snap2store.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import com.snap2store.backend.snap2store.model.Media;
import com.snap2store.backend.snap2store.repository.MediaRepository;

import java.util.List;

@RestController
@RequestMapping("/api/media")
public class MediaController {

    @Autowired
    private MediaRepository mediaRepository;

    // GET all media
    @GetMapping
    public List<Media> getAllMedia() {
        return mediaRepository.findAll();
    }

    // GET by type (e.g., "Game", "Book")
    @GetMapping("/type/{type}")
    public List<Media> getByType(@PathVariable String type) {
        return mediaRepository.findByType(type);
    }

    // POST new media
    @PostMapping
    public Media createMedia(@RequestBody Media media) {
        return mediaRepository.save(media);
    }
}
