package com.axa.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * AXA DevSecOps Reference Application.
 *
 * Trivially small Spring Boot app. The application itself is not the lesson;
 * the CI/CD pipeline around it is. See README.md and docs/PIPELINE.md.
 */
@SpringBootApplication
public class DemoApplication {

    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }
}
