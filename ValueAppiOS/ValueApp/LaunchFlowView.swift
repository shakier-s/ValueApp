import SwiftUI

struct LaunchFlowView: View {
    @AppStorage("valueapp.onboarding.completed") private var completedOnboarding = false
    @State private var showingSplash = true

    var body: some View {
        ZStack {
            if ProcessInfo.processInfo.environment["VALUEAPP_SCREENSHOT_MODE"] == "discover" { RootView() }
            else if ProcessInfo.processInfo.environment["VALUEAPP_SCREENSHOT_MODE"] == "savings" { MarketingIntroView(icon: "tag.fill", title: "Save more on every visit", detail: "Enjoy buy-one-get-one-free coupons, percentage discounts and instant money-off deals.", accent: .valueCoral) }
            else if ProcessInfo.processInfo.environment["VALUEAPP_SCREENSHOT_MODE"] == "redeem" { MarketingIntroView(icon: "ticket.fill", title: "Redeem in seconds", detail: "Save a coupon, show it at the shop and redeem securely. No paper coupons and no complicated steps.", accent: .green) }
            else if ProcessInfo.processInfo.environment["VALUEAPP_SCREENSHOT_MODE"] == "intro-1" { IntroductionView(initialPage: 0) {} }
            else if ProcessInfo.processInfo.environment["VALUEAPP_SCREENSHOT_MODE"] == "intro-2" { IntroductionView(initialPage: 1) {} }
            else if ProcessInfo.processInfo.environment["VALUEAPP_SCREENSHOT_MODE"] == "intro-3" { IntroductionView(initialPage: 2) {} }
            else if showingSplash { SplashView().transition(.opacity) }
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

private struct MarketingIntroView: View {
    let icon: String
    let title: String
    let detail: String
    let accent: Color
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) { Image(systemName: "ticket.fill"); Text("ValueApp").font(.title2.bold()); Spacer() }.foregroundStyle(Color.valuePurple).padding(.horizontal, 28).padding(.top, 28)
            Spacer()
            Image(systemName: icon).font(.system(size: 70)).foregroundStyle(.white).frame(width: 150, height: 150).background(accent.gradient, in: RoundedRectangle(cornerRadius: 40)).shadow(color: accent.opacity(0.25), radius: 22, y: 12)
            VStack(spacing: 16) { Text(title).font(.largeTitle.bold()).multilineTextAlignment(.center); Text(detail).font(.title2).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(5) }.padding(.horizontal, 30).padding(.top, 34)
            Spacer()
            Text("Great deals. Real savings.").font(.headline).foregroundStyle(Color.valuePurple).padding(.bottom, 42)
        }.background(Color.valueCream.ignoresSafeArea())
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
    @State private var page: Int
    init(initialPage: Int = 0, finish: @escaping () -> Void) { self.finish = finish; _page = State(initialValue: initialPage) }
    private let pages = [
        IntroPage(icon: "sparkles", title: "Discover value nearby", detail: "Find exclusive offers from restaurants, cafés, retailers and local favourites—all in one place.", accent: Color.valuePurple),
        IntroPage(icon: "tag.fill", title: "Save more on every visit", detail: "Enjoy buy-one-get-one-free coupons, percentage discounts and instant money-off deals.", accent: Color.valueCoral),
        IntroPage(icon: "ticket.fill", title: "Redeem in seconds", detail: "Save a coupon, show it at the shop and redeem securely. No paper coupons and no complicated steps.", accent: .green)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack { Spacer(); Button("Skip", action: finish).foregroundStyle(.secondary).padding() }
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 22) {
                        Spacer()
                        Image(systemName: item.icon).font(.system(size: 68)).foregroundStyle(.white).frame(width: 140, height: 140).background(item.accent.gradient, in: RoundedRectangle(cornerRadius: 38)).shadow(color: item.accent.opacity(0.25), radius: 22, y: 12)
                        VStack(spacing: 12) { Text(item.title).font(.title.bold()).foregroundStyle(Color.primary).multilineTextAlignment(.center); Text(item.detail).font(.title3).foregroundStyle(Color.secondary).multilineTextAlignment(.center).lineSpacing(4) }.padding(.horizontal, 28)
                        Spacer()
                    }.tag(index)
                }
            }.tabViewStyle(.page(indexDisplayMode: .always))
            Button(page == pages.count - 1 ? "Start saving" : "Continue") { if page == pages.count - 1 { finish() } else { withAnimation { page += 1 } } }.font(.headline).frame(maxWidth: .infinity).padding().background(Color.valuePurple, in: RoundedRectangle(cornerRadius: 18)).foregroundStyle(.white).padding(24)
        }.background(Color.valueCream.ignoresSafeArea())
    }
}

private struct IntroPage { let icon: String; let title: String; let detail: String; let accent: Color }
