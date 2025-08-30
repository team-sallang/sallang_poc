package com.example.demo.controller;

import com.example.demo.dto.SignalMessage;
import com.example.demo.service.FirebaseSignalingService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/signal")
@RequiredArgsConstructor
public class FirebaseSignalingController {

    private final FirebaseSignalingService signalingService;

    @PostMapping("/send")
    public ResponseEntity<String> sendSignal(@RequestBody SignalMessage message) {
        signalingService.sendSignal(message);
        return ResponseEntity.ok("Signal sent to Firebase");
    }
}