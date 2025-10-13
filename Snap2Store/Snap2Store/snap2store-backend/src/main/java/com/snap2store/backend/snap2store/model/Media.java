package com.snap2store.backend.snap2store.model;


import jakarta.persistence.*;

@Entity
@Table(name = "/Media")

public class Media {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long mediaId;
    private String title;
    private String type;
    private String condition;
    private String aiTag;
    private String imageUrl;


    //constructor
    public Media(Long mediaId, String title, String type, String condition, String aiTag, String imageUrl) {
        this.mediaId = mediaId;
        this.title = title;
        this.type = type;
        this.condition = condition;
        this.aiTag = aiTag;
        this.imageUrl = imageUrl;
    }

    //getter and setter
    public Long getMediaId() {
        return mediaId;
    }

    public void setMediaId(Long mediaId) {
        this.mediaId = mediaId;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }

    public String getCondition() {
        return condition;
    }

    public void setCondition(String condition) {
        this.condition = condition;
    }

    public String getAiTag() {
        return aiTag;
    }

    public void setAiTag(String aiTag) {
        this.aiTag = aiTag;
    }

    public String getImageUrl() {
        return imageUrl;
    }

    public void setImageUrl(String imageUrl) {
        this.imageUrl = imageUrl;
    }
}
