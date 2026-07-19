//
//  DateRangePicker.swift
//  Steepish
//

import SwiftUI

// MARK: - Date Range Picker

/// Lets the user view a fixed start date (always today) and select an end date via a sheet.
struct DateRangePicker: View {

    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var hasSelectedEndDate: Bool
    @Binding var showError: Bool
    @State private var showEndPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            Text("Period")
                .font(.custom("RussoOne-Regular", size: 18))
                .foregroundStyle(Color.light1)

            HStack(spacing: 16) {
                // From Date (Disabled - Always Today)
                VStack(alignment: .leading, spacing: 4) {
                    Text("From")
                        .font(.custom("RussoOne-Regular", size: 12))
                        .foregroundStyle(Color.light2)

                    // Display only - not clickable
                    Text(startDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.custom("RussoOne-Regular", size: 14))
                        .foregroundStyle(Color.light1.opacity(1.0))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 40)
                                .fill(Color.white.opacity(1.0))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 40)
                                        .stroke(Color.light4.opacity(0.35), lineWidth: 1)
                                )
                        )
                }

                // To Date (User can select)
                VStack(alignment: .leading, spacing: 4) {
                    Text("To")
                        .font(.custom("RussoOne-Regular", size: 12))
                        .foregroundStyle(Color.light2)

                    Button {
                        showEndPicker.toggle()
                    } label: {
                        Text(hasSelectedEndDate
                             ? endDate.formatted(date: .abbreviated, time: .omitted)
                             : "Ex: 6 Mar 2026")
                            .font(.custom("RussoOne-Regular", size: 14))
                            .foregroundStyle(
                                hasSelectedEndDate
                                    ? Color.light1
                                    : Color.light1.opacity(0.6)
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 40)
                                    .fill(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 40)
                                            .stroke(Color.light4.opacity(0.35), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showEndPicker) {
            DatePickerSheet(
                title: "End Date",
                selectedDate: $endDate,
                minimumDate: Calendar.current.date(byAdding: .day, value: 1, to: startDate),
                maximumDate: nil
            )
            .presentationDetents([.height(400)])
            .onDisappear {
                hasSelectedEndDate = true
                showError = false
            }
        }
        .onAppear {
            // Ensure start date is always today
            startDate = Date()
        }
    }
}

// MARK: - Date Picker Sheet

/// Modal graphical date picker used to select the challenge end date.
private struct DatePickerSheet: View {

    let title: String
    @Binding var selectedDate: Date
    let minimumDate: Date?
    let maximumDate: Date?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                DatePicker(
                    "",
                    selection: $selectedDate,
                    in: dateRange(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(Color.light2)
                .padding()

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.custom("RussoOne-Regular", size: 18))
                        .foregroundStyle(Color.light3)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 26)
                                .fill(Color.light1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// Clamps the picker's selectable range to the configured minimum/maximum dates.
    private func dateRange() -> ClosedRange<Date> {
        let min = minimumDate ?? Date.distantPast
        let max = maximumDate ?? Date.distantFuture
        return min...max
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var start = Date()
        @State private var end = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        @State private var hasSelected = false
        @State private var showError = false

        var body: some View {
            ZStack {
                Color.light3.ignoresSafeArea()
                DateRangePicker(
                    startDate: $start,
                    endDate: $end,
                    hasSelectedEndDate: $hasSelected,
                    showError: $showError
                )
                .padding()
            }
        }
    }

    return PreviewWrapper()
}

