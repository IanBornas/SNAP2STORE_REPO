package com.snap2store.backend.snap2store.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import com.snap2store.backend.snap2store.model.Location;
import com.snap2store.backend.snap2store.repository.LocationRepository;

import java.util.List;

@RestController
@RequestMapping("/api/locations")
public class LocationController {

    @Autowired
    private LocationRepository locationRepository;

    // GET all locations
    @GetMapping
    public List<Location> getAllLocations() {
        return locationRepository.findAll();
    }

    // GET verified locations
    @GetMapping("/verified")
    public List<Location> getVerifiedLocations() {
        return locationRepository.findByVerifiedTrue();
    }

    // POST - add new location
    @PostMapping
    public Location createLocation(@RequestBody Location location) {
        return locationRepository.save(location);
    }
}
