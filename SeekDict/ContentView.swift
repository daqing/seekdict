import SwiftUI
import Playgrounds
import SeekDictCore

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            LookupFieldRepresentable()
                .frame(height: 32)
            Text("SeekDictCore \(SeekDictCore.version)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 320)
    }
}

#Preview {
    ContentView()
}

#Playground {
    _ = 1 + 2
}
