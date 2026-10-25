import SwiftUI
import PlainDomain
import PlainDesignSystem

struct NotePhotoGallery: View {
    let photos: [NotePhoto]
    var editable = false
    /// When set, tapping a photo places it in the text instead of opening it.
    var onPlace: ((NotePhoto) -> Void)?
    @Environment(NotesStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opened: NotePhoto?
    @State private var deleting: NotePhoto?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(photos) { photo in
                    Button { if let onPlace { onPlace(photo) } else { opened = photo } } label: {
                        if let image = UIImage(data: photo.thumbnail) {
                            Image(uiImage: image)
                                .resizable().scaledToFill()
                                .frame(width: editable ? 84 : 180, height: editable ? 84 : 150)
                                .clipped()
                                .clipShape(.rect(cornerRadius: editable ? 18 : 24))
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: onPlace == nil ? "arrow.up.left.and.arrow.down.right" : "text.insert")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(7)
                                        .background(.black.opacity(0.35), in: .circle)
                                        .padding(7)
                                }
                        }
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel(onPlace == nil ? "Open photo" : "Place in text")
                    .accessibilityIdentifier("photo-\(photo.id)")
                    .overlay(alignment: .topTrailing) {
                        if editable {
                            Button { deleting = photo } label: {
                                Image(systemName: "minus").font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.black).frame(width: 26, height: 26)
                                    .background(.white, in: .circle).padding(5)
                            }
                            .accessibilityLabel("Remove photo")
                        }
                    }
                    .contextMenu {
                        if let onPlace {
                            Button("Place in text", systemImage: "text.insert") { onPlace(photo) }
                            Button("Open photo", systemImage: "arrow.up.left.and.arrow.down.right") { opened = photo }
                        }
                        if editable {
                            Button("Remove photo", systemImage: "trash", role: .destructive) { deleting = photo }
                        }
                    }
                    .transition(.scale(scale: reduceMotion ? 1 : 0.85).combined(with: .opacity))
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: photos.map(\.id))
        .sheet(item: $opened) { photo in
            PhotoViewer(photos: photos, selectedID: photo.id)
        }
        .confirmationDialog("Remove this photo?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Remove photo", role: .destructive) {
                if let deleting { store.deletePhoto(deleting.id) }
                deleting = nil
            }
        }
    }
}

struct PhotoViewer: View {
    let photos: [NotePhoto]
    @State var selectedID: UUID
    @Environment(NotesStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Photos").font(PlainFont.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).padding(14)
                        .background(.white.opacity(0.12), in: .circle)
                }
                .accessibilityLabel("Close")
            }
            .foregroundStyle(.white)
            .padding(20)

            TabView(selection: $selectedID) {
                ForEach(photos) { photo in
                    PhotoPage(photo: photo).tag(photo.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
        }
        .background(.black)
        .presentationBackground(.black)
        .preferredColorScheme(.dark)
    }
}

private struct PhotoPage: View {
    let photo: NotePhoto
    @Environment(NotesStore.self) private var store
    @State private var image: UIImage?
    @GestureState private var magnification = 1.0

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
                    .scaleEffect(min(max(magnification, 1), 3))
                    .gesture(MagnifyGesture().updating($magnification) { value, state, _ in state = value.magnification })
                    .accessibilityLabel("Photo")
            } else {
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: photo.id) {
            image = UIImage(data: store.photoData(photo.id) ?? photo.thumbnail)
        }
    }
}
