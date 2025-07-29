//
//  SearchResultsView.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/7/29.
//

import SwiftUI

struct SearchResultsView: View {
    let departureLocation: String
    let destination: String
    let departureDate: Date
    let returnDate: Date
    let budget: Double
    let onPrevious: () -> Void
    
    @State private var selectedTab = 0
    @State private var sortOption = 0 // 0: 价格, 1: 时长, 2: 出发时间
    
    let tabs = ["机票", "酒店", "行程"]
    let sortOptions = ["价格", "时长", "出发时间"]
    
    var body: some View {
        VStack(spacing: 0) {
     
            
            // 内容区域
            ScrollView {
                VStack(spacing: 16) {
                    // 搜索状态提示
                    VStack(spacing: 20) {
                        Image(systemName: "airplane.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        VStack(spacing: 8) {
                            Text("正在搜索中...")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("正在为您寻找从\(departureLocation.isEmpty ? "中国" : departureLocation)到\(destination)的最佳行程选项")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // 搜索参数显示
                        VStack(alignment: .leading, spacing: 12) {
                            SearchInfoRow(
                                icon: "location.circle",
                                title: "出发地",
                                value: departureLocation.isEmpty ? "中国" : departureLocation
                            )
                            
                            SearchInfoRow(
                                icon: "location",
                                title: "目的地",
                                value: destination
                            )
                            
                            SearchInfoRow(
                                icon: "calendar",
                                title: "出发日期",
                                value: departureDate.formatted(.dateTime.year().month().day())
                            )
                            
                            SearchInfoRow(
                                icon: "calendar",
                                title: "返回日期",
                                value: returnDate.formatted(.dateTime.year().month().day())
                            )
                            
                            SearchInfoRow(
                                icon: "yensign.circle",
                                title: "预算",
                                value: "¥ \(Int(budget))"
                            )
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.05))
                        )
                        
                        // 加载动画
                        HStack(spacing: 8) {
                            ForEach(0..<3, id: \.self) { index in
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(1.0)
                                    .animation(
                                        Animation.easeInOut(duration: 0.6)
                                            .repeatForever()
                                            .delay(Double(index) * 0.2),
                                        value: UUID()
                                    )
                            }
                        }
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 40)
                }
            }
            .background(Color.white)
            
            // 底部按钮
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
                
                Button(action: {
                    // 开始搜索功能
                }) {
                    HStack {
                        Text("查看结果")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
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
            .background(Color.white)
        }
        .background(Color.white)
    }
}

struct SearchInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    SearchResultsView(
        departureLocation: "北京",
        destination: "东京",
        departureDate: Date(),
        returnDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
        budget: 10000,
        onPrevious: {}
    )
}
