package com.snap2store.backend.snap2store.model;

import jakarta.persistence.*;
import org.springframework.security.core.userdetails.User;

import java.time.LocalDateTime;

@Entity
@Table(name = "Posts")
public class Post {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long postId;

    @ManyToOne
    @JoinColumn(name = "user_id")
    private User user;

    @ManyToOne
    @JoinColumn(name = "media_id")
    private Media media;

    private String description;
    private String storeName;
    private String address;
    private Double latitude;
    private Double longitude;
    private LocalDateTime createdAt;

    public Post(Long postId, LocalDateTime createdAt, Double longitude, Double
                        latitude, String address,
                String storeName, String description, Media media, User user) {
        this.postId = postId;
        this.createdAt = createdAt;
        this.longitude = longitude;
        this.latitude = latitude;
        this.address = address;
        this.storeName = storeName;
        this.description = description;
        this.media = media;
        this.user = user;
    }

    public Long getPostId() {
        return postId;
    }

    public void setPostId(Long postId) {
        this.postId = postId;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public Double getLongitude() {
        return longitude;
    }

    public void setLongitude(Double longitude) {
        this.longitude = longitude;
    }

    public Double getLatitude() {
        return latitude;
    }

    public void setLatitude(Double latitude) {
        this.latitude = latitude;
    }

    public String getAddress() {
        return address;
    }

    public void setAddress(String address) {
        this.address = address;
    }

    public String getStoreName() {
        return storeName;
    }

    public void setStoreName(String storeName) {
        this.storeName = storeName;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public Media getMedia() {
        return media;
    }

    public void setMedia(Media media) {
        this.media = media;
    }

    public User getUser() {
        return user;
    }

    public void setUser(User user) {
        this.user = user;
    }
}
