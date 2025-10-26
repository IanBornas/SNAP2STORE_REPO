package com.snap2store.backend.snap2store.service;

import com.google.cloud.vision.v1.*;
import com.google.protobuf.ByteString;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.List;

public class ImageAnalysisService {

    public static void analyzeImage(String filePath) throws Exception {
        try (ImageAnnotatorClient vision = ImageAnnotatorClient.create()) {
            ByteString imgBytes = ByteString.readFrom(Files.newInputStream(Paths.get(filePath)));
            Image img = Image.newBuilder().setContent(imgBytes).build();
            Feature feat = Feature.newBuilder().setType(Feature.Type.LABEL_DETECTION).build();
            AnnotateImageRequest request =
                    AnnotateImageRequest.newBuilder().addFeatures(feat).setImage(img).build();
            List<AnnotateImageResponse> responses = vision.batchAnnotateImages(List.of(request)).getResponsesList();
            for (AnnotateImageResponse res : responses) {
                res.getLabelAnnotationsList().forEach(annotation -> {
                    System.out.println("Label: " + annotation.getDescription());
                });
            }
        }
    }
}
