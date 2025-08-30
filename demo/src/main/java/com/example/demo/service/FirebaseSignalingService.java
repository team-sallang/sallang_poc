package com.example.demo.service;

import com.example.demo.dto.SignalMessage;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import org.springframework.stereotype.Service;

@Service
public class FirebaseSignalingService {

    private final DatabaseReference databaseRef = FirebaseDatabase.getInstance().getReference();

    public void sendSignal(SignalMessage message) {
        String roomPath = "calls/" + message.getReceiverId();
        databaseRef.child(roomPath).push().setValueAsync(message);
    }
}