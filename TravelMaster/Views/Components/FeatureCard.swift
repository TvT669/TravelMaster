//
//  FeatureCard.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/7/29.
//

import SwiftUI

struct FeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(iconColor)
                .frame(width: 50, height: 50)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.2))
        )
    }
}

struct TripCard: View {
    let trip: Trip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "airplane")
                    .foregroundColor(.orange)
                Text(trip.destination)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.departureDate.formatted(.dateTime.year().month().day()))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                    Text(trip.returnDate.formatted(.dateTime.year().month().day()))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            
            HStack {
                Image(systemName: "yensign.circle")
                    .foregroundColor(.green)
                Text("¥ \(Int(trip.budget))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
        }
        .frame(width: 160, height: 100)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.2))
        )
    }
}

struct SampleTripCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "airplane")
                    .foregroundColor(.orange)
                Text("东京")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("2025年7月22日")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                    Text("2025年7月29日")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            
            HStack {
                Image(systemName: "yensign.circle")
                    .foregroundColor(.green)
                Text("¥ 10,000")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
        }
        .frame(width: 160, height: 100)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.2))
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        // FeatureCard 预览
        HStack(spacing: 16) {
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
        }
        
        // TripCard 预览
        HStack(spacing: 16) {
            SampleTripCard()
            
        }
    }
    .padding()
    .background(
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.4, green: 0.6, blue: 1.0),
                Color(red: 0.6, green: 0.4, blue: 1.0)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
