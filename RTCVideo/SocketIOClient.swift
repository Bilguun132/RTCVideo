//
//  SocketIOClient.swift
//  RTCVideo
//
//  Created by Bilguun Batbold on 31/7/18.
//  Copyright © 2018 Bilguun Batbold. All rights reserved.
//

import Foundation
import Starscream
import SwiftyJSON
import WebRTC
import SocketIO

protocol SignalIOClientDelegate: class {
    func signalIOClientDidConnect(_ signalClient: SignalIOClient)
    func signalIOClientDidDisconnect(_ signalClient: SignalIOClient)
    func signalIOClient(_ signalClient: SignalIOClient, didReceiveRemoteSdp sdp: RTCSessionDescription)
    func signalIOClient(_ signalClient: SignalIOClient, didReceiveCandidate candidate: RTCIceCandidate)
}


class SignalIOClient {
    
    private let serverUrl = "http://192.168.1.130:3000"
    private let manager: SocketManager
    private let socket: SocketIOClient
    private var room: Room!
    weak var delegate: SignalIOClientDelegate?
    
    init() {
        manager = SocketManager(socketURL: URL(string: serverUrl)!, config: [.log(true), .compress])
        socket = manager.defaultSocket
        socket.on(clientEvent: .connect) {data, ack in
            self.delegate?.signalIOClientDidConnect(self)
        }
        socket.on(clientEvent: .disconnect) {data, ack in
            self.delegate?.signalIOClientDidDisconnect(self)
        }
    }
    
    func connect() {
        socket.connect()
        room = Room(dict: [
            "title": "test" as AnyObject,
            "key": "12345" as AnyObject
            ])
        socket.once("connect") {[weak self] data, ack in
            guard let this = self else {
                return
            }
            this.socket.emit("create_room", this.room.toDict())
        }
        
    }
    
    func disconnect() {
        socket.disconnect()
    }
    
    
    func send(sdp: RTCSessionDescription) {
        var type = "offer"
        switch sdp.type {
        case RTCSdpType.offer:
            type = "offer"
        case RTCSdpType.answer:
            type = "answer"
        default:
            return
        }
        socket.emit("sendOffer", [
            "roomKey": room.key,
            "type": type,
            "sdp": sdp.sdp
            ])
    }
    
    func send(candidate: RTCIceCandidate) {
    }
    
}

struct Room {
    
    var key: String
    var title: String
    
    init(dict: [String: AnyObject]) {
        title = dict["title"] as! String
        key = dict["key"] as! String
    }
    
    func toDict() -> [String: AnyObject] {
        return [
            "title": title as AnyObject,
            "key": key as AnyObject
        ]
    }
}
