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
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)

                Text("PetScans")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
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
