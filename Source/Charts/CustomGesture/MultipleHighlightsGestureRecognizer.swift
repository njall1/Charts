//
//  MultipleHighlightsGestureRecognizer.swift
//  Charts
//
//  Created by v.rusinov on 11/03/2020.
//

import UIKit.UIGestureRecognizerSubclass

final class MultipleHighlightsGestureRecognizer: UIGestureRecognizer {
    
    enum GestureType {
        case noTouch
        case oneTouch(UITouch)
        case twoTouches(UITouch, UITouch)
    }
    
    var oneTouchHandlingDelay: TimeInterval = 0.1
    var gestureType: GestureType = .noTouch
    
    private var delayedTouchHandlingWork: DispatchWorkItem?
    private var delayedTouch: UITouch? {
        willSet {
            if newValue == nil {
                self.delayedTouchHandlingWork?.cancel()
                self.delayedTouchHandlingWork = nil
            }
        }
    }
    private var delayedTouchInitialLocation: CGPoint = .zero
    private let delayedTouchMoveToFailThreshold: CGFloat = 5

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard !touches.isEmpty else { return }
        
        let correctedGesture: GestureType
        if let delayedTouch = self.delayedTouch,
            case .noTouch = self.gestureType {
            correctedGesture = .oneTouch(delayedTouch)
        } else {
            correctedGesture = self.gestureType
        }
        
        switch correctedGesture {
        case .noTouch:
            if touches.count == 1 {
                self.delayedTouch = touches.first
                self.delayedTouchInitialLocation = self.delayedTouch?.location(in: nil) ?? .zero
                let delayedTouchHandlingWork = DispatchWorkItem {
                    [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.handleDelayedTouchTimeout()
                }
                self.delayedTouchHandlingWork = delayedTouchHandlingWork
                DispatchQueue.main.asyncAfter(deadline: .now() + self.oneTouchHandlingDelay,
                                              execute: delayedTouchHandlingWork)
                return
            } else {
                let twoTouches = Array(touches.prefix(2))
                self.gestureType = .twoTouches(twoTouches.first!, twoTouches.last!)
                touches.subtracting(twoTouches).forEach { self.ignore($0, for: event) }
            }
        case .oneTouch(let touch):
            if let newTouch = touches.first {
                self.gestureType = .twoTouches(touch, newTouch)
                touches.forEach {
                    if $0 != newTouch {
                        self.ignore($0, for: event)
                    }
                }
            }
        case .twoTouches:
            touches.forEach { self.ignore($0, for: event) }
        }
        
        self.delayedTouch = nil
        if self.state == .began || self.state == .changed {
            self.state = .changed
        } else {
            self.state = .began
        }
    }
    
    private func handleDelayedTouchTimeout() {
        guard self.state == .possible,
            let touch = self.delayedTouch
        else { return }
        
        self.gestureType = .oneTouch(touch)
        self.delayedTouch = nil
        self.state = .began
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        if self.state == .possible,
            let delayedTouch = self.delayedTouch {
            let currentLocation = delayedTouch.location(in: nil)
            
            if hypot(currentLocation.x - self.delayedTouchInitialLocation.x,
                     currentLocation.y - self.delayedTouchInitialLocation.y) > self.delayedTouchMoveToFailThreshold {
                self.delayedTouch = nil
                self.state = .failed
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        self.handleTouchesEnd(touches, isCancelled: false)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        self.handleTouchesEnd(touches, isCancelled: true)
    }
    
    private func handleTouchesEnd(_ touches: Set<UITouch>, isCancelled: Bool) {
        switch self.gestureType {
        case .noTouch:
            if let delayedTouch = self.delayedTouch, touches.contains(delayedTouch) {
                self.delayedTouch = nil
            }
        case .oneTouch(let touch):
            if touches.contains(touch) {
                self.gestureType = .noTouch
                self.state = isCancelled ? .cancelled : .ended
            }
        case let .twoTouches(firstTouch, secondTouch):
            let firstTouchAffected = touches.contains(firstTouch)
            let secondTouchAffected = touches.contains(secondTouch)
            if firstTouchAffected && secondTouchAffected {
                self.gestureType = .noTouch
                self.state = isCancelled ? .cancelled : .ended
            } else if !(firstTouchAffected || secondTouchAffected) {
                return
            } else {
                self.gestureType = .oneTouch(firstTouchAffected ? secondTouch : firstTouch)
                self.state = .changed
            }
        }
    }
    
    override func reset() {
        self.gestureType = .noTouch
        self.delayedTouch = nil
        self.state = .possible
    }
    
}
