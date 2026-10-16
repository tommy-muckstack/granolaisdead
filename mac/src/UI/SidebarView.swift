import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: NoteStore
    @State private var renaming: UUID?
    @State private var draftName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Color.clear.frame(width: 70, height: 1)
                IconButton(symbol: "sidebar.left", help: "Hide sidebar  ⌘S") { model.sidebarVisible = false }
                IconButton(symbol: "magnifyingglass", help: "Search  ⌘K") { model.searchPresented = true }
                Spacer()
            }
            .frame(height: 52)

            row("Home", "house", selected: model.route == .home) { model.go(.home) }
            row("Chat", "bubble.left", selected: model.route == .chat) { model.go(.chat) }

            HStack {
                Text("Folders").font(G.Fonts.ui(13, .medium)).foregroundStyle(G.Colors.textSecondary)
                Spacer()
                IconButton(symbol: "plus", help: "New folder", size: 12) {
                    let f = store.createFolder("New folder"); renaming = f.id; draftName = f.name
                }
            }
            .padding(.leading, 10).padding(.top, 22).padding(.bottom, 4)

            ForEach(store.folders) { f in
                if renaming == f.id {
                    TextField("Folder name", text: $draftName, onCommit: {
                        store.renameFolder(f.id, to: draftName.trimmingCharacters(in: .whitespaces).isEmpty ? "New folder" : draftName)
                        renaming = nil
                    })
                    .textFieldStyle(.plain).font(G.Fonts.ui(14))
                    .padding(.horizontal, 10).frame(height: 32)
                    .background(RoundedRectangle(cornerRadius: G.Radius.md).fill(G.Colors.surfaceHover))
                } else {
                    row(f.name, "folder.fill", selected: model.route == .folder(f.id), count: store.notes.filter { $0.folderID == f.id }.count) {
                        model.go(.folder(f.id))
                    }
                    .contextMenu {
                        Button("Rename") { renaming = f.id; draftName = f.name }
                        Button("Delete folder", role: .destructive) {
                            store.deleteFolder(f.id); if model.route == .folder(f.id) { model.go(.home) }
                        }
                    }
                }
            }
            if store.folders.isEmpty {
                Text("Group notes by project or person.").font(G.Fonts.ui(12.5)).foregroundStyle(G.Colors.textTertiary)
                    .padding(.horizontal, 10)
            }

            Spacer()
            HStack(spacing: 4) {
                IconButton(symbol: "gearshape", help: "Settings  ⌘,") { SettingsWindow.shared.show() }
                IconButton(symbol: "arrow.down.circle", help: "Check for updates") { (NSApp.delegate as? AppDelegate)?.checkForUpdates() }
                IconButton(symbol: "chevron.left.forwardslash.chevron.right", help: "Source on GitHub") { (NSApp.delegate as? AppDelegate)?.openGitHub() }
                Spacer()
            }
            .padding(.leading, 4)
            HStack(spacing: 8) {
                Image(systemName: "lock.open").font(.system(size: 12)).foregroundStyle(G.Colors.textSecondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Free forever").font(G.Fonts.ui(13, .medium))
                    Text("No account. Notes stay on this Mac.").font(G.Fonts.ui(11.5)).foregroundStyle(G.Colors.textSecondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: G.Radius.lg).strokeBorder(G.Colors.border))
            .padding(.top, 6).padding(.bottom, 14)
        }
        .padding(.horizontal, 10)
        .background(G.Colors.sidebar)
    }

    private func row(_ title: String, _ symbol: String, selected: Bool, count: Int? = nil, action: @escaping () -> Void) -> some View {
        SidebarRow(title: title, symbol: symbol, selected: selected, count: count, action: action)
    }
}

private struct SidebarRow: View {
    let title: String, symbol: String, selected: Bool
    var count: Int?
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 13)).frame(width: 18).foregroundStyle(G.Colors.textSecondary)
                Text(title).font(G.Fonts.ui(14)).lineLimit(1)
                Spacer()
                if let count, count > 0 { Text("\(count)").font(G.Fonts.ui(12)).foregroundStyle(G.Colors.textTertiary) }
            }
            .padding(.horizontal, 10).frame(height: 32)
            .background(RoundedRectangle(cornerRadius: G.Radius.md).fill(selected ? G.Colors.surface : hover ? G.Colors.surfaceHover : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
