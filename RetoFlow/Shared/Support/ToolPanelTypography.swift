import SwiftUI

enum ToolPanelTypography {
    // 各工具页分组标题、拖拽区标题、列表区标题的统一字号。
    static let panelTitleSize: CGFloat = 16
    // 面板说明文案、辅助提示、路径说明等常规灰字字号。
    static let supportingTextSize: CGFloat = 11
    // 补充说明里更弱一层的信息，例如格式支持说明。
    static let compactSupportingTextSize: CGFloat = 11
    // 空列表时功能说明卡片的主标题字号。
    // 拖拽区主图标字号
    static let dropZoneIconSize: CGFloat = 32

    // 工具页说明体系统一使用常规字重，避免局部标题过重。
    static let regularWeight: Font.Weight = .regular
    // 标题类文字使用的字重
    static let boldWeight: Font.Weight = .medium

    // MARK: - Composed Fonts

    /// 面板标题字体 — 16pt Medium，用于工具页分组标题和拖拽区标题。
    static let panelTitle: Font = .system(size: panelTitleSize, weight: boldWeight)
    /// 面板正文字体 — 16pt Regular，用于列表区标题和配置行标签。
    static let panelBody: Font = .system(size: panelTitleSize, weight: regularWeight)
    /// 辅助说明字体 — 11pt Regular，用于路径说明、提示灰字。
    static let supporting: Font = .system(size: supportingTextSize, weight: regularWeight)
    /// 紧凑辅助字体 — 11pt Regular，用于格式说明等更弱层级信息。
    static let compactSupporting: Font = .system(size: compactSupportingTextSize, weight: regularWeight)
}
