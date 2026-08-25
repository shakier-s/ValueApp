import SwiftUI

struct LaunchFlowView: View {
    @AppStorage("valueapp.onboarding.completed") private var completedOnboarding = false
    @State private var showingSplash = true

    var body: some View {
        ZStack {
            if showingSplash { SplashView().transition(.opacity) }
            else if !completedOnboarding { IntroductionView { completedOnboarding = true }.transition(.opacity) }
            else { RootView().transition(.opacity) }
        }
        .animation(.easeInOut(duration: 0.35), value: showingSplash)
        .animation(.easeInOut(duration: 0.35), value: completedOnboarding)
        .task {
            try? await Task.sleep(for: .seconds(1.4))
            showingSplash = false
        }
    }
}

private struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.valuePurple, .valuePurple.opacity(0.78), .valueCoral], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "ticket.fill").font(.system(size: 72)).foregroundStyle(.white).padding(26).background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 30))
                Text("ValueApp").font(.system(size: 42, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text("More value. Every day.").font(.headline).foregroundStyle(.white.opacity(0.88))
            }
        }
    }
}

private struct IntroductionView: View {
    let finish: () -> Void
    @State private var page = 0
    private let pages = [
        IntroPage(icon: "sparkles", title: "Discover value nearby", detail: "Find exclusive offers from restaurants, cafés, retailers and local favourites—all in one place.", accent: Color.valuePurple),
        IntroPage(icon: "tag.fill", title: "Save more on every visit", detail: "Enjoy buy-one-get-one-free vouchers, percentage discounts and instant money-off deals.", accent: Color.valueCoral),
        IntroPage(icon: "ticket.fill", title: "Redeem in seconds", detail: "Save a voucher, show it at the shop and redeem securely. No paper coupons and no complicated steps.", accent: .green)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack { Spacer(); Button("Skip", action: finish).foregroundStyle(.secondary).padding() }
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 28) {
                        Spacer()
                        Image(systemName: item.icon).font(.system(size: 76)).foregroundStyle(.white).frame(width: 154, height: 154).background(item.accent.gradient, in: RoundedRectangle(cornerRadius: 42)).shadow(color: item.accent.opacity(0.25), radius: 22, y: 12)
                        VStack(spacing: 14) { Text(item.title).font(.largeTitle.bold()).foregroundStyle(Color.primary).multilineTextAlignment(.center); Text(item.detail).font(.title3).foregroundStyle(Color.secondary).multilineTextAlignment(.center).lineSpacing(4) }.padding(.horizontal, 28)
                        Spacer()
                    }.tag(index)
                }
            }.tabViewStyle(.page(indexDisplayMode: .always))
            Button(page == pages.count - 1 ? "Start saving" : "Continue") { if page == pages.count - 1 { finish() } else { withAnimation { page += 1 } } }.font(.headline).frame(maxWidth: .infinity).padding().background(Color.valuePurple, in: RoundedRectangle(cornerRadius: 18)).foregroundStyle(.white).padding(24)
        }.background(Color.valueCream.ignoresSafeArea())
    }
}

private struct IntroPage { let icon: String; let title: String; let detail: String; let accent: Color }
