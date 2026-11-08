//
//  NotchlyHeader.swift
//  Notchly
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Defaults
import SwiftUI

struct NotchlyHeader: View {
    @EnvironmentObject var vm: NotchlyViewModel
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var coordinator = NotchlyViewCoordinator.shared
    @StateObject var tvm = ShelfStateViewModel.shared
    var body: some View {
        HStack(spacing: 0) {
            HStack {
                if vm.notchState == .open {
                    TabSelectionView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .zIndex(2)

            if vm.notchState == .open {
                Rectangle()
                    .fill(NSScreen.screen(withUUID: coordinator.selectedScreenUUID)?.safeAreaInsets.top ?? 0 > 0 ? .black : .clear)
                    .frame(width: vm.closedNotchSize.width)
                    .mask {
                        NotchShape()
                    }
            }

            HStack(spacing: 2) {
                if vm.notchState == .open {
                    if isHUDType(coordinator.sneakPeek.type) && coordinator.sneakPeek.show {
                        OpenNotchHUD(type: $coordinator.sneakPeek.type, value: $coordinator.sneakPeek.value, icon: $coordinator.sneakPeek.icon)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    } else {
                        if isTabAvailable(.weather) {
                            Button {
                                withAnimation(.smooth) { coordinator.currentView = .weather }
                            } label: {
                                Image(systemName: NotchViews.weather.icon)
                                    .foregroundColor(coordinator.currentView == .weather ? .white : .gray)
                                    .imageScale(.medium)
                                    .frame(width: openNotchTabWidth, height: 30)
                                    .background {
                                        if coordinator.currentView == .weather {
                                            Capsule().fill(Color(nsColor: .secondarySystemFill))
                                        }
                                    }
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Weather")
                        }
                        if Defaults[.showMirror] {
                            Button(action: {
                                vm.toggleCameraPreview()
                            }) {
                                Capsule()
                                    .fill(.clear)
                                    .frame(width: openNotchTabWidth, height: 30)
                                    .contentShape(Capsule())
                                    .overlay {
                                        Image(systemName: "web.camera")
                                            .foregroundColor(.white)
                                            .imageScale(.medium)
                                    }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        Button(action: {
                            DispatchQueue.main.async {
                                SettingsWindowController.shared.showWindow()
                            }
                        }) {
                            Image(systemName: "gear")
                                .foregroundColor(.white)
                                .imageScale(.medium)
                                .frame(width: openNotchTabWidth, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Settings")
                    }
                }
            }
            .font(.system(.headline, design: .rounded))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .zIndex(2)
        }
        .foregroundColor(.gray)
        .environmentObject(vm)
    }

    func isHUDType(_ type: SneakContentType) -> Bool {
        switch type {
        case .volume, .brightness, .backlight, .mic, .capsLock:
            return true
        default:
            return false
        }
    }
}

#Preview {
    NotchlyHeader().environmentObject(NotchlyViewModel())
}
