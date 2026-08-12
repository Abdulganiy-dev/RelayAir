//
//  RippleModifier.swift
//  RelayAirMobile
//
//  Applies the Ripple Metal layer effect, and exposes it as an AnyTransition.
//

import SwiftUI

/// A modifier that applies a ripple effect to its content via `ShaderLibrary.Ripple`.
struct RippleModifier: ViewModifier, Animatable {
    var origin: CGPoint
    var elapsedTime: TimeInterval
    var duration: TimeInterval
    var amplitude: Double
    var frequency: Double
    var decay: Double
    var speed: Double

    var animatableData: Double {
        get { elapsedTime }
        set { elapsedTime = newValue }
    }

    init(
        origin: CGPoint,
        elapsedTime: TimeInterval,
        duration: TimeInterval,
        amplitude: Double = 12,
        frequency: Double = 15,
        decay: Double = 8,
        speed: Double = 1200
    ) {
        self.origin = origin
        self.elapsedTime = elapsedTime
        self.duration = duration
        self.amplitude = amplitude
        self.frequency = frequency
        self.decay = decay
        self.speed = speed
    }

    func body(content: Content) -> some View {
        let shader = ShaderLibrary.Ripple(
            .float2(origin),
            .float(elapsedTime),
            .float(amplitude),
            .float(frequency),
            .float(decay),
            .float(speed)
        )

        let maxSampleOffset = maxSampleOffset
        let elapsedTime = elapsedTime
        let duration = duration

        content.visualEffect { view, _ in
            view.layerEffect(
                shader,
                maxSampleOffset: maxSampleOffset,
                isEnabled: 0 < elapsedTime && elapsedTime < duration
            )
        }
    }

    var maxSampleOffset: CGSize {
        CGSize(width: amplitude, height: amplitude)
    }

    static let defaultDuration: TimeInterval = 0.7
}

/// Plays a ripple on the current view whenever `trigger` changes.
struct RippleEffect<T: Equatable>: ViewModifier {
    var origin: CGPoint
    var trigger: T
    var amplitude: Double
    var frequency: Double
    var decay: Double
    var speed: Double

    init(
        at origin: CGPoint,
        trigger: T,
        amplitude: Double = 12,
        frequency: Double = 12,
        decay: Double = 5,
        speed: Double = 700
    ) {
        self.origin = origin
        self.trigger = trigger
        self.amplitude = amplitude
        self.frequency = frequency
        self.decay = decay
        self.speed = speed
    }

    func body(content: Content) -> some View {
        let origin = origin
        let duration = duration
        let amplitude = amplitude
        let frequency = frequency
        let decay = decay
        let speed = speed

        content.keyframeAnimator(
            initialValue: 0.0,
            trigger: trigger
        ) { view, elapsedTime in
            view.modifier(
                RippleModifier(
                    origin: origin,
                    elapsedTime: elapsedTime,
                    duration: duration,
                    amplitude: amplitude,
                    frequency: frequency,
                    decay: decay,
                    speed: speed
                )
            )
        } keyframes: { _ in
            MoveKeyframe(0)
            LinearKeyframe(duration, duration: duration)
        }
    }

    var duration: TimeInterval { RippleModifier.defaultDuration }
}

extension AnyTransition {
    /// A ripple wave that runs from `origin` as the view inserts or removes.
    static func ripple(
        origin: CGPoint,
        duration: TimeInterval = 2,
        amplitude: Double = 12,
        frequency: Double = 15,
        decay: Double = 8,
        speed: Double = 1200
    ) -> AnyTransition {
        .modifier(
            active: RippleModifier(
                origin: origin,
                elapsedTime: 0,
                duration: duration,
                amplitude: amplitude,
                frequency: frequency,
                decay: decay,
                speed: speed
            ),
            identity: RippleModifier(
                origin: origin,
                elapsedTime: duration,
                duration: duration,
                amplitude: amplitude,
                frequency: frequency,
                decay: decay,
                speed: speed
            )
        )
    }
}
