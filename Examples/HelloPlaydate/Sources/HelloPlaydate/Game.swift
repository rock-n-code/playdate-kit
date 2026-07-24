//
//  Game.swift
//  A minimal Playdate game built on the play-date Swift bindings: a
//  bouncing box, a crank-aimed needle, button logging, and a system menu
//  item.
//

import CPlaydate
import PlayDate

@_cdecl("eventHandler")
public func eventHandler(
    pointer: UnsafeMutableRawPointer,
    event: PDSystemEvent,
    argument: UInt32
) -> Int32 {
    if case .initialize = SystemEvent(event: event, argument: argument) {
        Playdate.initialize(with: pointer)   // must happen before anything else
        Game.shared.start()
    }

    return 0
}

final class Game {
    nonisolated(unsafe) static let shared = Game()

    private var x: Float = 200
    private var y: Float = 120
    private var dx: Float = 3
    private var dy: Float = 2
    private let boxSize = 24

    func start() {
        Display.setRefreshRate(50)

        System.addMenuItem(title: "reset") { _ in
            Game.shared.reset()
        }

        System.setUpdateCallback {
            Game.shared.update()
            return true   // redraw the display this frame
        }
    }

    private func reset() {
        x = 200
        y = 120
    }

    private func update() {
        moveBox()
        handleInput()
        draw()
    }

    private func moveBox() {
        let width = Float(Display.width)
        let height = Float(Display.height)

        x += dx
        y += dy
        if x < 0 || x > width - Float(boxSize) { dx = -dx }
        if y < 24 || y > height - Float(boxSize) { dy = -dy }
    }

    private func handleInput() {
        let (_, pushed, _) = System.buttonState
        if pushed.contains(.a) {
            System.log("A pressed at \(System.currentTimeMilliseconds)ms")
        }
        if pushed.contains(.b) {
            (dx, dy) = (-dx, -dy)
        }
    }

    private func draw() {
        Graphics.clear(color: .white)
        Graphics.drawText("Hëllo from Swift — Ⓑ reverses", x: 8, y: 4)
        Graphics.fillRect(x: Int(x), y: Int(y), width: boxSize, height: boxSize, color: .black)

        if !System.isCrankDocked {
            // A needle from the screen center pointing where the crank points.
            let radians = System.crankAngle * .pi / 180
            let centerX = Display.width / 2
            let centerY = Display.height / 2
            Graphics.drawLine(
                x1: centerX, y1: centerY,
                x2: centerX + Int(40 * sinf(radians)),
                y2: centerY - Int(40 * cosf(radians)),
                width: 2, color: .xor)
        }

        System.drawFPS(x: 380, y: 4)
    }
}
