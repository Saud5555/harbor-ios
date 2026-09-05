import SwiftUI
import UIKit

struct PlayerHostView: UIViewRepresentable {
    let controller: VLCPlayerController

    final class RenderView: UIView {}

    func makeUIView(context: Context) -> UIView {
        let view = RenderView()
        view.backgroundColor = .black
        controller.attach(drawable: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
