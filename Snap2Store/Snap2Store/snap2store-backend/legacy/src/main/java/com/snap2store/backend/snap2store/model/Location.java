package com.snap2store.backend.snap2store.model;

import jakarta.persistence.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "/Location")
public class Location {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private String location_id;

    private String storeName;
    private String address;
    private Double latitude;
    private Double longitude;
    private LocalDateTime addedAt;
    private Boolean verified;

    @OneToOne
    @JoinColumn(name = "post_id")
    private Post post;




}
