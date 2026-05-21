import SwiftUI

struct NetRadioBrowserView: View {
    @ObservedObject private var api      = HertzAPIService.shared
    @ObservedObject private var settings = HertzSettings.shared
    @ObservedObject private var state    = NetRadioBrowserState.shared

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ────────────────────────────────────────────────
            HStack(spacing: 6) {
                if state.stack.count > 1 {
                    Button(action: goBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }

                Text(state.current?.name ?? "Net Radio")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                if state.isLoading {
                    ProgressView().controlSize(.mini)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)

            // ── Search bar ────────────────────────────────────────────
            if state.searchIndex >= 0 {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("Search…", text: $state.searchText)
                        .font(.system(size: 12))
                        .onSubmit { submitSearch() }
                    if !state.searchText.isEmpty {
                        Button(action: { state.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(white: 0.15).cornerRadius(6))
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
            }

            // ── Error ─────────────────────────────────────────────────
            if let err = state.errorMsg {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
            }

            // ── List ──────────────────────────────────────────────────
            if let layer = state.current {
                let visible = layer.items.filter { !$0.isSearch }
                if visible.isEmpty && !state.isLoading {
                    Text("No items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    ForEach(visible) { item in
                        Button(action: { tap(item: item, in: layer) }) {
                            HStack(spacing: 8) {
                                Image(systemName: item.isDirectory ? "folder" :
                                      item.isPlayable ? "dot.radiowaves.left.and.right" : "magnifyingglass")
                                    .font(.system(size: 11))
                                    .foregroundColor(item.isPlayable ? settings.schemeColor : .secondary)
                                    .frame(width: 16)

                                Text(item.text)
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                Spacer()

                                if item.isDirectory {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 7)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(state.isLoading)

                        Divider().padding(.leading, 28)
                    }
                }
            } else if !state.isLoading {
                Button("Browse Net Radio") { loadRoot() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
        .onAppear { if state.stack.isEmpty { loadRoot() } }
    }

    // MARK: - Actions

    private func loadRoot() {
        state.isLoading = true
        state.errorMsg = nil
        state.stack = []
        api.resetNetRadioToRoot {
            api.fetchNetRadioListFull { result in
                state.isLoading = false
                switch result {
                case .success(let layer):
                    state.stack = [layer]
                    updateSearchIndex(for: layer)
                case .failure:
                    state.errorMsg = "Could not load Net Radio."
                }
            }
        }
    }

    private func goBack() {
        guard state.stack.count > 1 else { return }
        state.stack.removeLast()
        state.searchText = ""
        if let cur = state.stack.last { updateSearchIndex(for: cur) }
        else { state.searchIndex = -1 }
    }

    private func tap(item: NetRadioListItem, in layer: NetRadioLayer) {
        guard !state.isLoading else { return }
        state.isLoading = true
        state.errorMsg = nil

        if item.isPlayable {
            print("[Browser] PLAY: layer=\(layer.layer) index=\(item.id) attr=\(item.attribute) text=\(item.text)")
            api.playNetRadioItem(layer: layer.layer, index: item.id) { ok in
                print("[Browser] play result: \(ok)")
                self.state.isLoading = false
            }
        } else {
            // Directory — navigate and fetch
            api.selectNetRadioItem(layer: layer.layer, index: item.id) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.api.fetchNetRadioListFull { result in
                        self.state.isLoading = false
                        switch result {
                        case .success(let newLayer):
                            self.state.stack.append(newLayer)
                            self.updateSearchIndex(for: newLayer)
                            self.state.searchText = ""
                        case .failure:
                            self.state.errorMsg = nil
                        }
                    }
                }
            }
        }
    }

    private func submitSearch() {
        guard !state.searchText.isEmpty, state.searchIndex >= 0 else { return }
        state.isLoading = true
        state.errorMsg = nil
        api.searchNetRadio(layer: state.searchLayer, index: state.searchIndex, query: state.searchText) { ok in
            guard ok else { self.state.isLoading = false; self.state.errorMsg = "Search failed. Try again."; return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.api.fetchNetRadioListFull { result in
                    self.state.isLoading = false
                    switch result {
                    case .success(let newLayer):
                        self.state.stack.append(newLayer)
                        self.updateSearchIndex(for: newLayer)
                    case .failure:
                        self.state.errorMsg = "Search failed. Try again."
                    }
                }
            }
        }
    }

    private func updateSearchIndex(for layer: NetRadioLayer) {
        if let item = layer.items.first(where: { $0.isSearch }) {
            state.searchIndex = item.id
            state.searchLayer = layer.layer
        } else {
            state.searchIndex = -1
        }
    }
}
