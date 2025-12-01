import Cocoa

protocol DragDropViewDelegate: AnyObject {
    func didDropFile(url: URL)
}

class DragDropView: NSView {

    weak var delegate: DragDropViewDelegate?
    
    private var isDragging = false {
        didSet {
            needsDisplay = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        registerForDraggedTypes([.fileURL])
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if isDragging {
            NSColor.secondaryLabelColor.set()
            let path = NSBezierPath(rect: bounds)
            path.lineWidth = 4
            path.stroke()
        }
        
        let text = "Drag & Drop Media File Here"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let size = text.size(withAttributes: attrs)
        let point = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        text.draw(at: point, withAttributes: attrs)
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        isDragging = true
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDragging = false
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDragging = false
        
        guard let pasteboard = sender.draggingPasteboard.propertyList(forType: .fileURL) as? String,
              let url = URL(string: pasteboard) else {
            return false
        }
        
        delegate?.didDropFile(url: url)
        return true
    }
}
