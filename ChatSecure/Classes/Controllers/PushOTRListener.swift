//
//  PushOTRListener.swift
//  ChatSecure
//
//  Created by David Chiles on 9/29/15.
//  Copyright © 2015 Chris Ballinger. All rights reserved.
//

import Foundation
import ChatSecure_Push_iOS

/**
* Listen for changes from EncryptionManager for changes in state and when detetced going encrypted
* ensures push token is transfered
*/
class PushOTRListener: NSObject {
    
    let queue = NSOperationQueue()
    var notification:NSObjectProtocol?
    weak var storage:PushStorageProtocol?
    weak var pushController:PushController?
    weak var tlvHandler:OTRPushTLVHandlerProtocol?
    
    init (storage:PushStorageProtocol?, pushController:PushController?, tlvHandler:OTRPushTLVHandlerProtocol?) {
        self.storage = storage
        self.pushController = pushController
        self.tlvHandler = tlvHandler
        super.init()
        self.startObserving()
    }
    
    func startObserving() {
        self.notification = NSNotificationCenter.defaultCenter().addObserverForName(OTRMessageStateDidChangeNotification, object: nil, queue: self.queue) {[weak self] (notification) -> Void in
            self?.handleNotification(notification)
        }
    }
    
    func handleNotification(notification:NSNotification) {
        guard let buddy = notification.object as? OTRBuddy else {
            return
        }
        
        if let dictionary = notification.userInfo as? [String:AnyObject] {
            let number = dictionary[OTRMessageStateKey] as? NSNumber
            if let enumValue = number?.unsignedLongValue where enumValue == OTREncryptionMessageState.Encrypted.rawValue {
                
                
                if let account = self.storage?.account(buddy.accountUniqueId) {
                    //Everytime we're starting a new OTR Session we resend a new fresh push token either from the server or the cache
                    self.pushController?.getNewPushToken(buddy.uniqueId, completion: {[weak self] (t, error) -> Void in
                        if let token = t {
                            self?.sendOffToken(token, buddyUsername: buddy.username, accountUsername: account.username, protocol: account.protocolTypeString())
                        }
                    })
                }
            }
        }
    }
    
    func sendOffToken(token:Token, buddyUsername:String, accountUsername:String, `protocol`:String) -> Void {
        if let url = self.pushController?.apiClient.messageEndpont().absoluteString {
            let data = PushSerializer.serialize([token], APIEndpoint: url)
            self.tlvHandler?.sendPushData(data, username: buddyUsername, accountName:accountUsername  , protocol: `protocol`)
        }
    }
    
    deinit {
        if let token = self.notification {
            NSNotificationCenter.defaultCenter().removeObserver(token)
        }
    }

}