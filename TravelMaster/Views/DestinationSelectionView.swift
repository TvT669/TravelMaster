//
//  DestinationSelectionView.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/7/29.
//

import SwiftUI

struct DestinationSelectionView: View {
    @Binding var departureLocation: String
    @Binding var destination: String
     
    let onNext: () -> Void
    
  
    
    var body: some View {
        VStack(spacing: 0) {
           
            VStack(spacing: 30) {
                // 图标和标题
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "location.magnifyingglass")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 8) {
                        Text("选择您的目的地")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("输入您想去的城市或国家")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("出发地")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("例如：东京、巴黎、纽约...", text: $departureLocation)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                }
                // 搜索框
                VStack(alignment: .leading, spacing: 12) {
                    Text("目的地")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("例如：东京、巴黎、纽约...", text: $destination)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                }
                
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // 下一步按钮
            VStack(spacing: 16) {
                Button(action: onNext) {
                    HStack {
                        Text("下一步")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(destination.isEmpty ? Color.gray : Color.blue)
                    )
                }
                .disabled(destination.isEmpty)
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 30)
        }
        .background(Color.white)
    }
}

#Preview {
    DestinationSelectionView(
        departureLocation: .constant(""),
        destination: .constant(""),
        onNext: {}
    )
}
