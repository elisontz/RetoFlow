import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("RetoFlow 使用手册")
                        .font(.system(size: 34, weight: .bold))
                    Text("面向摄影后期工作流的专业辅助工具，助您高效管理图库。")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 24)

                // MARK: - 找到 RAW 文件
                HelpSection(title: "找到 RAW 文件", icon: "camera.viewfinder", color: .blue) {
                    HelpCard(title: "解决什么痛点？", content: "您是否习惯先在手机、平板或电脑上快速预览并筛选出几十张精选小图（JPG），但回头面对硬盘里成千上万张 RAW 原片时，却发现手动一张张找原片极其痛苦？")
                    HelpCard(title: "RetoFlow 是怎么做的？", content: "只需把那所有的“精选小图”丢进来，再指给它你的“RAW 总备份库”，RetoFlow 就会秒速帮你把对应的原片挑出来。你甚至可以一键用原片把这些小图直接替换掉，立刻开始后期修图。如果发现缺失RAW文件，你还可以一键复制缺失的RAW文件名到剪贴板，方便手动查找。")
                }

                // MARK: - 目录结构整理
                HelpSection(title: "目录结构整理", icon: "folder.badge.gearshape", color: .indigo) {
                    HelpCard(title: "解决什么痛点？", content: "修好的图（如导出的 JPG）全都乱糟糟地堆在一个文件夹里？想要让它们像原始素材一样，整齐地回到类似“2026-05-01/婚礼/相机A”这样的分层文件夹里？")
                    HelpCard(title: "RetoFlow 是怎么做的？", content: "它会参考你原始素材的文件夹层级，自动在你的成品目录里建好一模一样的子文件夹，并把对应的文件“送回家”。从此你的成品库和原始库目录结构完全同步。完全不需要手动一个一个文件夹的去新建！")
                }

                // MARK: - 文件重命名 (详细参考代码实现)
                HelpSection(title: "文件重命名规则", icon: "character.cursor.ibeam", color: .orange) {
                    VStack(spacing: 12) {
                        RuleGridItem(title: "替换文本", content: "查找指定字符串并替换为新内容。")
                        RuleGridItem(title: "正则表达式", content: "支持捕获组（如 $1, $2）进行高级匹配替换。")
                        RuleGridItem(title: "移除模式", content: "支持通配符（*test*）、位置范围、或特定内容前后移除。")
                        RuleGridItem(title: "序列号", content: "可自定义起始数字、位数（如 001）以及添加位置。")
                        RuleGridItem(title: "大小写转换", content: "一键切换全大写、全小写或首字母大写。")
                        RuleGridItem(title: "扩展名修改", content: "批量修改后缀（如 .jpeg 改为 .jpg）。")
                    }
                }

                // MARK: - 图片导出压缩
                HelpSection(title: "图片导出压缩", icon: "arrow.down.doc", color: .green) {
                    HelpCard(title: "尺寸与体积限制", content: "• 尺寸：支持锁定长边、短边、宽度或高度，系统将按比例缩放。\n• 体积：通过自适应算法，在满足目标大小（如 5MB）的前提下，尽可能保持最高画质。")
                    HelpCard(title: "元数据保留", content: "勾选“保留元数据”可确保 EXIF 信息（相机型号、镜头、拍摄参数）在压缩后不丢失。")
                }

                // MARK: - 通用技巧
                HelpSection(title: "通用技巧", icon: "lightbulb.fill", color: .yellow) {
                    VStack(alignment: .leading, spacing: 10) {
                        TipItem(text: "支持从访达（Finder）直接拖拽文件夹到虚线框内。")
                        TipItem(text: "双击列表中的行，可以直接在访达中定位该文件。")
                        TipItem(text: "右键点击列表行可呼出上下文菜单，可以复制文件名。")
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)
                }

                Spacer(minLength: 60)
            }
            .padding(40)
            .frame(maxWidth: 800, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - 辅助组件

struct HelpSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content

    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 32)
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            content
        }
    }
}

struct HelpCard: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(6)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

struct RuleGridItem: View {
    let title: String
    let content: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.orange.opacity(0.8))
                .frame(width: 6, height: 6)
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 12)
    }
}

struct TipItem: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.subheadline)
            Text(text)
                .font(.subheadline)
        }
    }
}
