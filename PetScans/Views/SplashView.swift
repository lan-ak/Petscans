import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            ColorTokens.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: SpacingTokens.lg) {
                Spacer()

                Image("AppIconImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: SpacingTokens.iconHero, height: SpacingTokens.iconHero)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)

                Text("PetScans")
                    .font(.custom("Quicksand", size: 28).weight(.bold))
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()

                ProgressView()
                    .tint(ColorTokens.brandPrimary)
                    .padding(.bottom, SpacingTokens.xxl)
            }
        }
    }
}

#Preview {
    SplashView()
}
