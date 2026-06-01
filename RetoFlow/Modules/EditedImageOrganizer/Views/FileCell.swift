import SwiftUI

struct FileCell: View {
    let file: ImageFile?
    let color: Color
    var alignRight: Bool = false
    
    var body: some View {
        if let file = file {
            HStack {
                if !alignRight {
                    Image(systemName: "photo")
                        .foregroundColor(color)
                }
                
                VStack(alignment: alignRight ? .trailing : .leading) {
                    Text(file.filename)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(file.url.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                if alignRight {
                    Image(systemName: "photo")
                        .foregroundColor(color)
                }
            }
            .padding(6)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(6)
        } else {
            // 空占位符
            Text("-")
                .foregroundColor(.secondary.opacity(0.3))
                .padding(6)
        }
    }
}
