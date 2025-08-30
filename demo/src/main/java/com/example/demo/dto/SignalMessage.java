package com.example.demo.dto;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class SignalMessage {
    private String senderId;
    private String receiverId;
    private String type; // offer, answer, candidate
    private String sdp;  // SDP or ICE candidate string
}