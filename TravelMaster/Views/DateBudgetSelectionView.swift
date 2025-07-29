//
//  DateBudgetSelectionView.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/7/29.
//

import SwiftUI

struct DateBudgetSelectionView: View {
    @Binding var departureDate: Date
    @Binding var returnDate: Date
    @Binding var selectedBudgetType: BudgetType
    @Binding var customBudget: Double
    let onNext: () -> Void
    let onPrevious: () -> Void
    
    @State private var showingCustomBudgetAlert = false
    @State private var customBudgetInput = ""
    
    var durationDays: Int {
        Calendar.current.dateComponents([.day], from: departureDate, to: returnDate).day ?? 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 30) {
                // 图标和标题
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 8) {
                        Text("设置出行时间和预算")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("选择出行日期和预算范围")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 日期选择
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("出发日期")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            DatePicker("", selection: $departureDate, displayedComponents: .date)
                                .datePickerStyle(CompactDatePickerStyle())
                                .accentColor(.blue)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("返回日期")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            DatePicker("", selection: $returnDate, displayedComponents: .date)
                                .datePickerStyle(CompactDatePickerStyle())
                                .accentColor(.blue)
                        }
                    }
                    
                    if durationDays > 0 {
                        Text("共 \(durationDays) 天")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                }
                .padding(.horizontal, 20)
                
                // 预算选择
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("预算范围（人民币）")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(BudgetType.allCases, id: \.self) { budget in
                            BudgetCard(
                                budgetType: budget,
                                isSelected: selectedBudgetType == budget,
                                action: {
                                    selectedBudgetType = budget
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // 自定义预算
                    Button(action: {
                        customBudgetInput = "\(Int(customBudget))"
                        showingCustomBudgetAlert = true
                    }) {
                        HStack {
                            Text("自定义：¥")
                            Text("\(Int(customBudget))")
                                .fontWeight(.semibold)
                        }
                        .font(.body)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            Spacer()
            
            // 按钮区域
            HStack(spacing: 16) {
                Button(action: onPrevious) {
                    Text("上一步")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                }
                
                Button(action: onNext) {
                    HStack {
                        Text("开始搜索")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Image(systemName: "magnifyingglass")
                        /*Text("下一步")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")*/
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.blue)
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(Color.white)
        .alert("自定义预算", isPresented: $showingCustomBudgetAlert) {
            TextField("输入预算金额", text: $customBudgetInput)
                .keyboardType(.numberPad)
            
            Button("确定") {
                if let amount = Double(customBudgetInput) {
                    customBudget = amount
                }
            }
            
            Button("取消", role: .cancel) {}
        } message: {
            Text("请输入您的预算金额")
        }
        .onChange(of: departureDate) { _, newValue in
            if returnDate <= newValue {
                returnDate = Calendar.current.date(byAdding: .day, value: 1, to: newValue) ?? newValue
            }
        }
    }
}

struct BudgetCard: View {
    let budgetType: BudgetType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text("¥ \(Int(budgetType.amount))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(budgetType.rawValue)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
            )
        }
    }
}

#Preview {
    DateBudgetSelectionView(
        departureDate: .constant(Date()),
        returnDate: .constant(Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()),
        selectedBudgetType: .constant(.comfortable),
        customBudget: .constant(10000),
        onNext: {},
        onPrevious: {}
    )
}
