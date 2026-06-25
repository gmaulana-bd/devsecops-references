package com.axa.demo;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;
import java.util.regex.Pattern;

/**
 * Minimal REST controller. Two endpoints, intentionally trivial.
 *
 * The /greet endpoint demonstrates server-side input validation (WAP-004),
 * even on a one-line application, because the principle matters more than
 * the size of the codebase.
 */
@RestController
public class ApiController {

    // Allow-list pattern: alphabetic characters, 1 to 50 characters.
    // Anything else is rejected. This is WAP-004 in one line of code.
    private static final Pattern SAFE_NAME = Pattern.compile("^[a-zA-Z]{1,50}$");

    @GetMapping("/")
    public Map<String, String> root() {
        return Map.of("message", "AXA DevSecOps Reference Application");
    }

    @GetMapping("/greet")
    public Map<String, String> greet(@RequestParam(defaultValue = "world") String name) {
        // Server-side input validation. Never trust the client.
        if (!SAFE_NAME.matcher(name).matches()) {
            return Map.of("error", "Invalid name parameter.");
        }
        return Map.of("message", "Hello, " + name);
    }
}
