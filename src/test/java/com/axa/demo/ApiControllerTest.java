package com.axa.demo;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Minimal integration test for the REST controller.
 *
 * Verifies that the input validation in /greet works as expected:
 * valid names get a greeting, invalid input gets an error message.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class ApiControllerTest {

    @LocalServerPort
    private int port;

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void rootEndpointReturnsApplicationName() {
        String response = restTemplate.getForObject("http://localhost:" + port + "/", String.class);
        assertThat(response).contains("AXA DevSecOps Reference Application");
    }

    @Test
    void greetWithValidNameReturnsGreeting() {
        String response = restTemplate.getForObject(
            "http://localhost:" + port + "/greet?name=Alice", String.class);
        assertThat(response).contains("Hello, Alice");
    }

    @Test
    void greetWithInjectionAttemptIsRejected() {
        // Try a SQL-injection-style payload; the allow-list should reject it.
        String response = restTemplate.getForObject(
            "http://localhost:" + port + "/greet?name=admin' OR '1'='1", String.class);
        assertThat(response).contains("Invalid name parameter");
    }
}
