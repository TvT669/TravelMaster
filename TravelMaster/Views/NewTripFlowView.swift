//
//  NewTripFlowView.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/7/29.
//

import SwiftUI

struct NewTripFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 1
    @State private var departureLocation = ""
    @State private var destination = ""
    @State private var departureDate = Date()
    @State private var returnDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var selectedBudgetType: BudgetType = .comfortable
    @State private var customBudget: Double = 10000
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // 导航栏
                    HStack {
                        Button("取消") {
                            dismiss()
                        }
                        .foregroundColor(.blue)
                        
                        Spacer()
                        // 进度指示器
                        HStack(spacing: 16) {
                            ForEach(1...3, id: \.self) { step in
                                HStack {
                                    Circle()
                                        .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Text("\(step)")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(step <= currentStep ? .white : .gray)
                                        )
                                    
                                    if step < 3 {
                                        Rectangle()
                                            .fill(step < currentStep ? Color.blue : Color.gray.opacity(0.3))
                                            .frame(width: 40, height: 2)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 20)
                        .background(Color.white)

                      
                        
                        Spacer()
                        
                        // 占位符保持居中
                        Text("取消")
                            .opacity(0)
                    }
                    .padding()
                    .background(Color.white)
                    
            
                    // 内容区域
                    switch currentStep {
                    case 1:
                        DestinationSelectionView(
                            departureLocation: $departureLocation,
                            destination: $destination,
                            onNext: nextStep
                        )
                    case 2:
                        DateBudgetSelectionView(
                            departureDate: $departureDate,
                            returnDate: $returnDate,
                            selectedBudgetType: $selectedBudgetType,
                            customBudget: $customBudget,
                            onNext: nextStep,
                            onPrevious: previousStep
                        )
                    case 3:
                        SearchResultsView(
                            departureLocation: departureLocation,
                            destination: destination,
                            departureDate: departureDate,
                            returnDate: returnDate,
                            budget: selectedBudgetType == .comfortable && customBudget != 10000 ? customBudget : selectedBudgetType.amount,
                            onPrevious: previousStep
                        )
                    default:
                        EmptyView()
                    }
                }
            }
        }
    }
    
    private func nextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = min(currentStep + 1, 3)
        }
    }
    
    private func previousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = max(currentStep - 1, 1)
        }
    }
}

#Preview {
    NewTripFlowView()
}
