import SwiftUI
import SwiftData

struct KidModeView: View {
    @Query(sort: \Member.sortOrder) private var members: [Member]
    @Environment(\.dismiss) private var dismiss
    @State private var kid: Member?
    @State private var celebrate = 0
    @State private var lastStars = 0

    private var kids: [Member] { members.filter(\.isKid) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [(kid?.color ?? .orange).opacity(0.25), .clear], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                header
                if let kid {
                    ChoreBoard(kid: kid) { stars in
                        lastStars = stars
                        celebrate += 1
                    }
                } else {
                    picker
                }
            }
            .padding(24)

            if celebrate > 0 {
                StarBurst(stars: lastStars)
                    .id(celebrate)
                    .allowsHitTesting(false)
            }
        }
        .onAppear { if kids.count == 1 { kid = kids.first } }
    }

    private var header: some View {
        HStack {
            if kid != nil && kids.count > 1 {
                Button { withAnimation { kid = nil } } label: {
                    Label("Switch", systemImage: "person.2.fill").font(.title3.bold())
                }
                .buttonStyle(.bordered)
            }
            Spacer()
            HoldToExit { dismiss() }
        }
    }

    private var picker: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("Who's helping today?")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
            HStack(spacing: 28) {
                ForEach(kids) { k in
                    Button { withAnimation(.spring) { kid = k } } label: {
                        VStack(spacing: 10) {
                            Avatar(member: k, size: 130)
                            Text(k.name).font(.title.bold())
                            Text("⭐ \(k.weekStars) this week").font(.title3).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct ChoreBoard: View {
    let kid: Member
    var onDone: (Int) -> Void

    private var chores: [Chore] {
        (kid.chores ?? [])
            .filter { !$0.isPaused && ($0.status <= .today || $0.isDoneToday) }
            .sorted { a, b in
                if a.isDoneToday != b.isDoneToday { return !a.isDoneToday }
                return a.title < b.title
            }
    }

    var body: some View {
        let todo = chores.filter { !$0.isDoneToday }.count
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                Avatar(member: kid, size: 70)
                VStack(alignment: .leading) {
                    Text("Hi \(kid.name)!").font(.system(size: 34, weight: .heavy, design: .rounded))
                    Text(todo == 0 ? "All done! Amazing! 🎉" : "\(todo) thing\(todo == 1 ? "" : "s") to do")
                        .font(.title3).foregroundStyle(.secondary)
                }
                Spacer()
                Text("⭐ \(kid.weekStars)")
                    .font(.system(size: 40, weight: .heavy, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 18)], spacing: 18) {
                    ForEach(chores) { chore in
                        KidTile(chore: chore, color: kid.color) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                if chore.isDoneToday {
                                    chore.undoToday()
                                } else {
                                    chore.complete(by: kid)
                                    onDone(chore.stars)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            if chores.isEmpty {
                Spacer()
                Text("Nothing for today. Go play! 🌈")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Spacer()
            }
        }
    }
}

struct KidTile: View {
    let chore: Chore
    let color: Color
    var tap: () -> Void

    var body: some View {
        let done = chore.isDoneToday
        Button(action: tap) {
            VStack(spacing: 14) {
                Image(systemName: done ? "checkmark.circle.fill" : (chore.room?.icon ?? "star"))
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(done ? Color.green : color)
                    .contentTransition(.symbolEffect(.replace))
                Text(chore.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .strikethrough(done)
                Text(String(repeating: "⭐", count: max(chore.stars, 1)))
                    .font(.title2)
                    .opacity(done ? 0.4 : 1)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(done ? Color.green.opacity(0.15) : color.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(done ? Color.green : color.opacity(0.5), lineWidth: 3)
            )
            .scaleEffect(done ? 0.96 : 1)
        }
        .buttonStyle(.plain)
    }
}

struct StarBurst: View {
    let stars: Int
    @State private var animate = false

    var body: some View {
        Text("⭐ +\(max(stars, 1))")
            .font(.system(size: 90, weight: .heavy, design: .rounded))
            .shadow(radius: 10)
            .scaleEffect(animate ? 1.3 : 0.3)
            .opacity(animate ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1)) { animate = true }
            }
    }
}

/// Exit button that needs a 1.5 second press, so little fingers don't leave Kid Mode by accident.
struct HoldToExit: View {
    var action: () -> Void
    @State private var pressing = false

    var body: some View {
        Label(pressing ? "Keep holding…" : "Hold to exit", systemImage: "lock.fill")
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.thinMaterial, in: Capsule())
            .overlay(
                Capsule().trim(from: 0, to: pressing ? 1 : 0)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .animation(pressing ? .linear(duration: 1.5) : .default, value: pressing)
            )
            .onLongPressGesture(minimumDuration: 1.5, perform: action) { pressing = $0 }
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }
}
