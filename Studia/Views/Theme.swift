import SwiftUI

// MARK: - Palette : fond noir profond, surfaces sombres, bleu seul accent,

enum Theme {
    static let background = Color(hex: 0x000000)
    static let surface = Color(hex: 0x121315)
    static let surfaceRaised = Color(hex: 0x1C1E21)
    static let border = Color(hex: 0x2A2D31)
    static let text = Color(hex: 0xFFFFFF)
    static let textSecondary = Color(hex: 0x9BA0A6)
    static let textTertiary = Color(hex: 0x6B7075)
    static let accent = Color(hex: 0x2E7CF6)
    static let accentSoft = Color(hex: 0x14263F)
    static let danger = Color(hex: 0xE5484D)
    static let dangerSoft = Color(hex: 0x2E1415)
}

extension Color {
    /// Permet Color(Theme.accent) sur iOS 16 : l'API SwiftUI équivalente exige iOS 17.
    init(_ color: Color) { self = color }

    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1)
    }
}

// MARK: - Composants partagés

struct Card<Content: View>: View {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(Color(Theme.surface))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color(Theme.border), lineWidth: 0.5)
            )
    }
}

struct SectionTitle: View {
    var text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(Theme.accent))
            }
            Text(text)
                .font(.headline)
                .foregroundStyle(Color(Theme.text))
        }
    }
}

struct BlueBadge: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(Theme.accentSoft))
            .foregroundStyle(Color(Theme.accent))
            .clipShape(Capsule())
    }
}

struct EmptyState: View {
    var icon: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color(Theme.textTertiary))
            Text(title)
                .font(.headline)
                .foregroundStyle(Color(Theme.text))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color(Theme.textSecondary))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }
}

struct ErrorState: View {
    var message: String
    var retryLabel: String = "Réessayer"
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color(Theme.danger))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color(Theme.textSecondary))
                .multilineTextAlignment(.center)
            if let onRetry {
                Button(retryLabel, action: onRetry)
                    .buttonStyle(.bordered)
                    .tint(Color(Theme.accent))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }
}

/// Écran de synchronisation : barre de progression réelle + libellé de l'étape.
struct SyncOverlay: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Studia")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(Color(Theme.accent))
            Text("Récupération de tes données Pronote")
                .font(.headline)
                .foregroundStyle(Color(Theme.text))

            VStack(spacing: 10) {
                ProgressView(value: model.syncProgress)
                    .progressViewStyle(.linear)
                    .tint(Color(Theme.accent))
                Text(model.syncLabel)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color(Theme.textSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .background(Color(Theme.surface))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
        .background(Color(Theme.background).ignoresSafeArea())
    }
}

// MARK: - Chiffres lisibles

struct StatCell: View {
    var label: String
    var value: String
    var icon: String
    var highlighted: Bool = false
    var alert: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption)
            }
            .foregroundStyle(Color(Theme.textSecondary))
            Text(value.isEmpty ? "—" : value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(alert && highlighted ? Color(Theme.danger) : highlighted ? Color(Theme.accent) : Color(Theme.text))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
