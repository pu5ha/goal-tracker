import SwiftUI
import MapKit
import Combine

// MARK: - Location Search Completer
class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    @Published var isSearching = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func search(query: String) {
        guard !query.isEmpty else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.results = completer.results
            self.isSearching = false
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.results = []
            self.isSearching = false
        }
    }
}

// MARK: - Location Search Field
struct LocationSearchField: View {
    @Binding var location: String
    @StateObject private var searchCompleter = LocationSearchCompleter()
    @State private var showSuggestions = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Text field
            HStack(spacing: 10) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(CyberTheme.neonMagenta)

                TextField("Search location...", text: $location)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(CyberTheme.textPrimary)
                    .focused($isFocused)
                    .onChange(of: location) { newValue in
                        searchCompleter.search(query: newValue)
                        showSuggestions = !newValue.isEmpty && isFocused
                    }
                    .onChange(of: isFocused) { focused in
                        showSuggestions = focused && !location.isEmpty && !searchCompleter.results.isEmpty
                    }

                if !location.isEmpty {
                    Button(action: {
                        location = ""
                        searchCompleter.results = []
                        showSuggestions = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(CyberTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(CyberTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isFocused ? CyberTheme.neonMagenta.opacity(0.5) : CyberTheme.gridLine, lineWidth: 1)
            )

            // Suggestions dropdown
            if showSuggestions && !searchCompleter.results.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(searchCompleter.results.prefix(5), id: \.self) { result in
                        Button(action: {
                            selectLocation(result)
                        }) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(CyberTheme.textPrimary)
                                    .lineLimit(1)

                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(CyberTheme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                        .background(Color.clear)

                        if result != searchCompleter.results.prefix(5).last {
                            Rectangle()
                                .fill(CyberTheme.gridLine)
                                .frame(height: 1)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(CyberTheme.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(CyberTheme.neonMagenta.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: CyberTheme.neonMagenta.opacity(0.2), radius: 8, x: 0, y: 4)
                .padding(.top, 4)
            }
        }
    }

    private func selectLocation(_ result: MKLocalSearchCompletion) {
        if result.subtitle.isEmpty {
            location = result.title
        } else {
            location = "\(result.title), \(result.subtitle)"
        }
        showSuggestions = false
        isFocused = false
    }
}
