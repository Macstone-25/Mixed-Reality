import Foundation

let task_ns = 15 * 1_000_000_000
let processor = SpeechProcessor()
print("starting test...")

Task {
    try? await Task.sleep(nanoseconds: UInt64(task_ns))
    
    print("stopping...")
    processor.deconfigureAudioEngine {
        print("finalizing file... script exiting.")
        exit(0)
    }
}

// This keeps the program alive while the Task above runs
RunLoop.main.run()
