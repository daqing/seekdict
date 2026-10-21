import SwiftUI
import Playgrounds
import SeekDictCore

struct ContentView: View {
    var body: some View {
        Text("SeekDictCore \(SeekDictCore.version)")
            .padding()
    }
}

#Preview {
    ContentView()
}

#Playground {
    _ = 1 + 2
}
