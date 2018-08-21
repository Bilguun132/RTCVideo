//
//  SignalClient.swift
//  WebRTC
//
//  Created by Stas Seldin on 20/05/2018.
//  Copyright © 2018 Stas Seldin. All rights reserved.
//

import Foundation
import Starscream
import SwiftyJSON
import WebRTC

protocol SignalClientDelegate: class {
    func signalClientDidConnect(_ signalClient: SignalClient)
    func signalClientDidDisconnect(_ signalClient: SignalClient)
    func signalClient(_ signalClient: SignalClient, didReceiveRemoteSdp sdp: RTCSessionDescription)
    func signalClient(_ signalClient: SignalClient, didReceiveCandidate candidate: RTCIceCandidate)
}

struct Message: Codable {
    enum PayloadType: String, Codable {
        case sdp, candidate
    }
    let type: PayloadType
    let payload: String
}

class SignalClient {
    
    private let serverUrl = "ws://137.132.165.237:3000"
    private let socket: WebSocket
    weak var delegate: SignalClientDelegate?
    
    init() {
        self.socket = WebSocket(url: URL(string: self.serverUrl)!)
    }
    func connect() {
        self.socket.delegate = self
        self.socket.connect()
    }
    func disconnect() {
        self.socket.disconnect()
    }
    
    func send(sdp: RTCSessionDescription) {
        let message = Message(type: .sdp, payload: sdp.jsonString() ?? "")
        if let dataMessage = try? JSONEncoder().encode(message),
            let stringMessage = String(data: dataMessage, encoding: .utf8) {
            self.socket.write(string: stringMessage)
        }
    }
    
    func send(candidate: RTCIceCandidate) {
        let message = Message(type: .candidate,
                              payload: candidate.jsonString() ?? "")
        if let dataMessage = try? JSONEncoder().encode(message),
            let stringMessage = String(data: dataMessage, encoding: .utf8){
            self.socket.write(string: stringMessage)
        }
    }
}


extension SignalClient: WebSocketDelegate {
    func websocketDidConnect(socket: WebSocketClient) {
        self.delegate?.signalClientDidConnect(self)
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        self.delegate?.signalClientDidDisconnect(self)
        
        // try to reconnect every two seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            print("Trying to reconnect to signaling server...")
            self.socket.connect()
        }
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        if let data = text.data(using: .utf8),
            let message = try? JSONDecoder().decode(Message.self, from: data) {
            switch message.type {
            case .candidate:
                if let candidate = RTCIceCandidate.fromJsonString(message.payload) {
                    self.delegate?.signalClient(self, didReceiveCandidate: candidate)
                }
            case .sdp:
                if let sdp = RTCSessionDescription.fromJsonString(message.payload) {
                    self.delegate?.signalClient(self, didReceiveRemoteSdp: sdp)
                }
            }
            return
        }
        let message = JSON.init(parseJSON: text)
        if message["sdp"].exists() {
            var type = RTCSdpType.answer
            if message["sdp"]["type"].stringValue == "offer" {
                type = RTCSdpType.offer
            }
            let sdp = RTCSessionDescription(type: type, sdp: message["sdp"]["sdp"].stringValue)
            self.delegate?.signalClient(self, didReceiveRemoteSdp: sdp)
        }
        if message["ice"].exists() {
            let ice = RTCIceCandidate(sdp:  message["ice"]["candidate"].stringValue, sdpMLineIndex:  message["ice"]["sdpMLineIndex"].int32Value, sdpMid:  message["ice"]["sdpMid"].stringValue)
            self.delegate?.signalClient(self, didReceiveCandidate: ice)
        }
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print(data)
    }
}
