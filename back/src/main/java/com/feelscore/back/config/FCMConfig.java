package com.feelscore.back.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

import java.io.IOException;
import java.io.InputStream;
import java.util.List;

@Configuration
public class FCMConfig {

    @Bean
    public FirebaseApp firebaseApp() throws IOException {
        if (!FirebaseApp.getApps().isEmpty()) {
            return FirebaseApp.getInstance();
        }

        String firebaseConfigPath = "firebase-service-account.json";
        ClassPathResource resource = new ClassPathResource(firebaseConfigPath);

        if (resource.exists()) {
            try (InputStream serviceAccount = resource.getInputStream()) {
                FirebaseOptions options = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                        .build();
                return FirebaseApp.initializeApp(options);
            }
        } else {
            System.out.println("WARNING: Firebase service account file not found at " + firebaseConfigPath);
            return null;
        }
    }
}
