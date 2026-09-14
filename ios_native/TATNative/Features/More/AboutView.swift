import SwiftUI

/// 關於，照 `about_page.dart`：貢獻者、隱私權條款；除錯版多一個開發人員選項。
struct AboutView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var showPolicy = false

  var body: some View {
    List {
      NavigationLink {
        ContributorsView(client: app.more)
      } label: {
        label(Lucide.award, L10n.Contribution)
      }
      Button {
        showPolicy = true
      } label: {
        label(Lucide.shieldCheck, L10n.PrivacyPolicy)
      }
      #if DEBUG
        NavigationLink {
          DeveloperView()
        } label: {
          label(Lucide.codeXml, L10n.developerMode)
        }
      #endif
    }
    .navigationTitle(L10n.about)
    .analyticsScreen("/AboutPage")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $showPolicy) { PrivacyPolicySheet() }
  }

  private func label(_ icon: LucideIcon, _ title: String) -> some View {
    HStack(spacing: 12) {
      LucideImage(icon, size: 20)
        .foregroundStyle(Color.tatBrand)
        .frame(width: 28)
      Text(title).foregroundStyle(Color.primary)
    }
  }
}

/// 貢獻者，照 `contributors_page.dart`：專案連結與 GitHub 上的貢獻者。
struct ContributorsView: View {
  let client: MoreClient
  @Environment(\.openURL) private var openURL
  @State private var contributors: [ProjectContributor]?
  @State private var failed = false

  private static let project = URL(string: "https://github.com/morris13579/tat_ntust")!

  var body: some View {
    List {
      Section(L10n.projectLink) {
        Button {
          openURL(Self.project)
        } label: {
          HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
              Text(L10n.github).foregroundStyle(Color.primary)
              Text(Self.project.absoluteString)
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
            }
            Spacer(minLength: 8)
            LucideImage(Lucide.externalLink, size: 16).foregroundStyle(Color(.secondaryLabel))
          }
        }
      }
      Section(L10n.Contributors) {
        if let contributors {
          ForEach(Array(contributors.enumerated()), id: \.offset) { _, contributor in
            row(contributor)
          }
        } else if failed {
          SectionEmptyState(message: L10n.somethingError, icon: Lucide.circleAlert)
        } else {
          ProgressView().frame(maxWidth: .infinity)
        }
      }
    }
    .navigationTitle(L10n.Contribution)
    .analyticsScreen("/ContributorsPage")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      guard contributors == nil else { return }
      if let list = try? await client.contributors() {
        contributors = list
      } else {
        failed = true
      }
    }
  }

  private func row(_ contributor: ProjectContributor) -> some View {
    Button {
      if let url = contributor.url.flatMap(URL.init(string:)) { openURL(url) }
    } label: {
      HStack(spacing: 12) {
        AvatarView(url: contributor.avatarUrl, size: 32)
        Text(contributor.login).foregroundStyle(Color.primary)
        Spacer(minLength: 8)
        if contributor.url != nil {
          LucideImage(Lucide.externalLink, size: 16).foregroundStyle(Color(.secondaryLabel))
        }
      }
    }
    .disabled(contributor.url == nil)
  }
}
