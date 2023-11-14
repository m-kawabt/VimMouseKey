import Cocoa
import Dispatch
import CoreGraphics

// 主ディスプレイのサイズの高さ
let MAIN_DISPLAY_HEIGHT: CGFloat = 1080
var PUSHED_KEY_LIST: [String] = []

@main
struct VimMouseKeyApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitors = [Any?]()
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("キーボードの読み取り許可: \(AXIsProcessTrusted())")
        var app: EnableApp? = nil
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { (event: NSEvent)-> Void in
            if event.modifierFlags.rawValue == 1573192 {
                if app == nil {
                    print("有効化")
                    app = EnableApp()
                } else {
                    print("無効化")
                    app = nil
                }
            }
        })
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor!)
        }
        monitors.removeAll()
    }
}

class EnableApp {
    var eventTap: CFMachPort?
    init() {
        run()
        let myMask = (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        self.eventTap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: CGEventMask(myMask), callback: {(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? in
            let keycode = event.getIntegerValueField(.keyboardEventKeycode)
            let isARepeat = event.getIntegerValueField(.keyboardEventAutorepeat)
            let flags = event.flags
            if flags.rawValue == 1573192 {
                return Unmanaged.passRetained(event)
            }
            if type == .keyDown {
                var newEvent: CGEvent = event
                if event.getIntegerValueField(.keyboardEventKeycode) == 46 { // スクロールダウン
                    newEvent = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: -3, wheel2: 0, wheel3: 0)!
                    return Unmanaged.passRetained(newEvent)
                } else if event.getIntegerValueField(.keyboardEventKeycode) == 32 { // スクロールアップ
                    newEvent = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: 3, wheel2: 0, wheel3: 0)!
                    return Unmanaged.passRetained(newEvent)
                } else if event.getIntegerValueField(.keyboardEventKeycode) == 34 { // 左スクロール
                    newEvent = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: 0, wheel2: 2, wheel3: 0)!
                    return Unmanaged.passRetained(newEvent)
                } else if event.getIntegerValueField(.keyboardEventKeycode) == 31 { // 右スクロール
                    newEvent = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: 0, wheel2: -2, wheel3: 0)!
                    return Unmanaged.passRetained(newEvent)
                } else if event.getIntegerValueField(.keyboardEventKeycode) == 36 { // 左クリック
                    clickLeftBottun()
                } else if isARepeat == 0 && (keycode ==  4 || keycode == 38 || keycode == 37 || keycode == 40) { // 各移動キー
                    PUSHED_KEY_LIST.append(keycodeToAlphabet(keycode: keycode, flags: flags))
                    print(PUSHED_KEY_LIST)
                }
            } else if type == .keyUp {
                for (i, key) in PUSHED_KEY_LIST.enumerated() {
                    if keycodeToAlphabet(keycode: keycode, flags: flags).lowercased() == key.lowercased() {
                        PUSHED_KEY_LIST.remove(at: i)
                    }
                }
                print(PUSHED_KEY_LIST)
            } else if type == .flagsChanged {
                if flags.contains(.maskShift) {
                    var upperKeyList: [String] = []
                    for key in PUSHED_KEY_LIST {
                        upperKeyList.append(key.uppercased())
                    }
                    PUSHED_KEY_LIST.removeAll()
                    PUSHED_KEY_LIST = upperKeyList
                } else {
                    var lowerKeyList: [String] = []
                    for key in PUSHED_KEY_LIST {
                        lowerKeyList.append(key.lowercased())
                    }
                    PUSHED_KEY_LIST.removeAll()
                    PUSHED_KEY_LIST = lowerKeyList
                }
                print(PUSHED_KEY_LIST)
            }
            return nil
        }, userInfo: nil)
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
        CFRunLoopRun()
    }
    
    deinit {
        CFMachPortInvalidate(self.eventTap)
        PUSHED_KEY_LIST.removeAll()
    }
    
    // 移動キーの入力キューを無限ループで参照
    func run() {
        let queue = DispatchQueue.global(qos: .background)
        queue.async{
            while true {
                let prePosition: CGPoint = CGPoint(x: NSEvent.mouseLocation.x, y: MAIN_DISPLAY_HEIGHT - NSEvent.mouseLocation.y)
                var newPosition: CGPoint = CGPoint(x: prePosition.x, y: prePosition.y)
                for key in PUSHED_KEY_LIST {
                    if let delta: CGPoint = keyToDelta(key: key) {
                        newPosition = CGPoint(x: newPosition.x + delta.x, y: newPosition.y + delta.y)
                        if prePosition.x != newPosition.x || prePosition.y != newPosition.y {
                            moveMousePointer(newLocation: newPosition)
                        }
                    }
                }
                usleep(1000)
            }
        }
    }
}

func keycodeToAlphabet(keycode: Int64, flags: CGEventFlags) -> String {
    if keycode == 4 {
        if flags.contains(.maskShift) {
            return "H"
        } else {
            return "h"
        }
    } else if keycode == 38 {
        if flags.contains(.maskShift) {
            return "J"
        } else {
            return "j"
        }
    } else if keycode == 40 {
        if flags.contains(.maskShift) {
            return "K"
        } else {
            return "k"
        }
    } else if keycode == 37 {
        if flags.contains(.maskShift) {
            return "L"
        } else {
            return "l"
        }
    }
    return "?"
}

enum EnableKey: String {
    case h = "h"
    case H = "H"
    case j = "j"
    case J = "J"
    case k = "k"
    case K = "K"
    case l = "l"
    case L = "L"
}

func keyToDelta(key: String) -> CGPoint? {
    var delta: CGPoint? = nil
    if let keyCase = EnableKey(rawValue: key) {
        switch keyCase {
        case .h:
            delta = CGPoint(x: -5, y: 0)
            print("Left")
        case .H:
            delta = CGPoint(x: -15, y: 0)
            print("Left Fast")
        case .j:
            delta = CGPoint(x: 0, y: 5)
            print("Down")
        case .J:
            delta = CGPoint(x: 0, y: 15)
            print("Down Fast")
        case .k:
            delta = CGPoint(x: 0, y: -5)
            print("Up")
        case .K:
            delta = CGPoint(x: 0, y: -15)
            print("Up Fast")
        case .l:
            delta = CGPoint(x: 5, y: 0)
            print("Right")
        case .L:
            delta = CGPoint(x: 15, y: 0)
            print("Right Fast")
        }
    }
    return delta
}

func moveMousePointer(newLocation: CGPoint) {
    // NSビューとCGウィンドウでは座標の基準位置が違う
    let mouseEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: newLocation, mouseButton: .left)
    mouseEvent?.flags = CGEventFlags()
    mouseEvent?.post(tap: CGEventTapLocation.cghidEventTap)
}

func clickLeftBottun(){
    let nscoord = NSEvent.mouseLocation
    let cgcoord: CGPoint = CGPoint(x: nscoord.x, y: MAIN_DISPLAY_HEIGHT - nscoord.y)
    let mouseDownEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: cgcoord, mouseButton: .left)
    let mouseUpEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: cgcoord, mouseButton: .left)
    mouseDownEvent?.flags = CGEventFlags() // OptionやCommandのフラグを消すために初期化する
    mouseUpEvent?.flags = CGEventFlags() // OptionやCommandのフラグを消すために初期化する
    mouseDownEvent?.post(tap: CGEventTapLocation.cghidEventTap)
    mouseUpEvent?.post(tap: CGEventTapLocation.cghidEventTap)
}
