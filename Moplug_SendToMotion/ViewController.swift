//
//  ViewController.swift
//  Moplug_On_Motion
//
//  Created by 垣原親伍 on 2025/12/01.
//

import Cocoa

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let dragDropView = DragDropView(frame: view.bounds)
        dragDropView.autoresizingMask = [.width, .height]
        dragDropView.delegate = self
        view.addSubview(dragDropView)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}

extension ViewController: DragDropViewDelegate {
    func didDropFile(url: URL) {
        print("Dropped file: \(url.path)")
        if let dragDropView = view.subviews.first(where: { $0 is DragDropView }) as? DragDropView {
            dragDropView.statusText = "Processing: \(url.lastPathComponent)\n\(url.path)"
        }
        // TODO: Generate Motion Project and Open it
        MotionController.shared.processDroppedFile(url: url)
    }
}

