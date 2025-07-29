//
//  ContentView.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/7/29.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [Trip]
    @State private var showingNewTripFlow = false

    var body: some View {
        NavigationStack {
            ZStack {
                // 渐变背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        //Color(red: 0.2, green: 0.39, blue: 0.2)//墨绿
                       // Color(red: 0.4, green: 0.9, blue: 0.5)//浅绿
                       Color(red: 0.4, green: 0.6, blue: 1.0)
                      //  Color(red: 0.6, green: 0.4, blue: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // 顶部区域
                        VStack(spacing: 20) {
                            // 飞机图标
                            Image(systemName: "airplane.departure")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                                .padding(.top, 40)
                            
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "airplane")
                                        .foregroundColor(.white)
                                    Text("键规划完美行程")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                
                               
                            }
                        }
                        .padding(.bottom, 40)
                        
                        // 功能卡片
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            FeatureCard(
                                icon: "magnifyingglass",
                                iconColor: .orange,
                                title: "智能搜索",
                                subtitle: "机票+酒店一站式搜索"
                            )
                            
                            FeatureCard(
                                icon: "map",
                                iconColor: .green,
                                title: "路线规划",
                                subtitle: "最优路线自动生成"
                            )
                            
                            FeatureCard(
                                icon: "dollarsign.circle",
                                iconColor: .blue,
                                title: "预算管理",
                                subtitle: "智能预算分配建议"
                            )
                            
                            FeatureCard(
                                icon: "bell",
                                iconColor: .red,
                                title: "价格提醒",
                                subtitle: "机票降价及时通知"
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                        
                        // 开始规划按钮
                        Button(action: {
                            showingNewTripFlow = true
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                    .font(.title2)
                                Text("开始规划新行程")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.black.opacity(0.3))
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                        
                        // 最近行程
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("最近行程")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(trips.prefix(5), id: \.id) { trip in
                                        TripCard(trip: trip)
                                    }
                                    
                                    // 示例卡片（如果没有数据）
                                    if trips.isEmpty {
                                        ForEach(0..<1, id: \.self) { _ in
                                            SampleTripCard()
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingNewTripFlow) {
            NewTripFlowView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Trip.self, inMemory: true)
}
