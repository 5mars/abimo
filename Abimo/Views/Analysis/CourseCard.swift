//
//  CourseCard.swift
//  Abimo
//
//  One compact "course" on the Taste Test menu — icon, avg score, and the
//  top point as a teaser. Tapping serves the full course in a detail sheet.
//

import SwiftUI

struct CourseCard: View {
    let course: SWOTCourse
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(course.kind.color.opacity(0.12))
                            .frame(width: 34, height: 34)
                        Image(systemName: course.kind.iconName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(course.kind.color)
                    }
                    Spacer()
                    if !course.items.isEmpty {
                        Text("avg \(Int(course.avgScore.rounded()))")
                            .font(.duoCaption)
                            .foregroundColor(course.kind.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(course.kind.color.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(course.kind.courseLabel)
                        .font(.duoCaption)
                        .foregroundColor(.textSec)
                    Text(course.kind.title)
                        .font(.duoCardTitle)
                        .foregroundColor(.textPri)
                }

                if let top = course.topItem {
                    Text(top.point)
                        .font(.system(size: 13))
                        .foregroundColor(.textSec)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(course.kind.emptyLine)
                        .font(.system(size: 13))
                        .foregroundColor(.textSec)
                        .italic()
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)

                if course.items.count > 1 {
                    Text("\(course.items.count) items")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(course.kind.color.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .buttonStyle(DuoCardButtonStyle(padding: 14))
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        CourseCard(course: SWOTCourse(
            kind: .strengths,
            items: [SWOTItem(point: "Clear pain point with proven willingness to pay", score: 78, category: "Demand")],
            avgScore: 78
        )) {}
        CourseCard(course: SWOTCourse(kind: .threats, items: [], avgScore: 0)) {}
    }
    .padding()
    .background(Color.appBg)
}
