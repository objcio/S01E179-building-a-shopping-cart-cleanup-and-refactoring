//
//  ContentView.swift
//  ShoppingCart
//
//  Created by Chris Eidhof on 22.10.19.
//  Copyright © 2019 Chris Eidhof. All rights reserved.
//

import SwiftUI

let colors = (0..<5).map { ix in
    Color(hue: Double(ix)/5, saturation: 1, brightness: 0.8)
}
let icons = ["airplane", "studentdesk", "hourglass", "headphones", "lightbulb"]

struct ShoppingItem: View {
    let index: Int
    var body: some View {
        RoundedRectangle(cornerRadius: 5)
           .fill(colors[index])
           .frame(width: 50, height: 50)
            .overlay(
                Image(systemName: icons[index])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.white)
                    .padding(10)
            )
    }
}

extension View {
    func overlayWithAnchor<A, V: View>(value: Anchor<A>.Source, transform: @escaping (Anchor<A>) -> V) -> some View {
        let key = TaggedKey<Anchor<A>, ()>.self

        return self
            .anchorPreference(key: key, value: value, transform: { $0 })
            .overlayPreferenceValue(key, { anchor in
                transform(anchor!)
            })
            .preference(key: key, value: nil)
    }
}

fileprivate struct AppearFrom: ViewModifier {
    let anchor: Anchor<CGPoint>
    @State private var didAppear: Bool = false
    
    func body(content: Content) -> some View {
        GeometryReader { proxy in
            content
                .offset(self.didAppear ? .zero : CGSize(width: proxy[self.anchor].x, height: proxy[self.anchor].y))
                .onAppear {
                    self.didAppear = true
                }
        }
    }
}

extension View {
    func appearFrom(anchor: Anchor<CGPoint>) -> some View {
        self.modifier(AppearFrom(anchor: anchor))
    }
}

prefix func -(size: CGSize) -> CGSize {
    CGSize(width: -size.width, height: -size.height)
}

// This key takes the first non-`nil` value
struct TaggedKey<Value, Tag>: PreferenceKey {
    static var defaultValue: Value? { nil }
    static func reduce(value: inout Value?, nextValue: () -> Value?) {
        value = value ?? nextValue()
    }
}

struct Draggable<Content: View>: View {
    let content: Content
    let snapBack: Bool
    let onDragged: (CGRect) -> ()
    let onTapped: (Anchor<CGPoint>) -> ()
    let onEnded: (Anchor<CGPoint>) -> ()
    
    @GestureState private var state: DragGesture.Value = nil
    
    var body: some View {
        let translation = state?.translation ?? .zero
        return ZStack {
            content
                .overlayWithAnchor(value: .point(CGPoint(x: translation.width, y: translation.height)), transform: { anchor in
                    Color.white.opacity(0.001)
                        .onTapGesture { self.onTapped(anchor) }
                        .highPriorityGesture(DragGesture().updating(self.$state, body: { (value, state, _) in
                            state = value
                        }).onEnded { _ in self.onEnded(anchor) })
                })
            if state != nil {
                content
                    .onGeometryChange(compute: { $0.frame(in: .global) }, onChange: onDragged)
                    .offset(state?.translation ?? .zero)
                    .animation(.default)
                    .transition(.offset(snapBack ? -(state?.translation ?? .zero) : .zero))
            }
        }
    }
}

extension View {
    func draggable(snapBack: Bool, onDragged: @escaping (CGRect) -> (), onTapped: @escaping (Anchor<CGPoint>) -> (), onEnded: @escaping (Anchor<CGPoint>) -> ()) -> some View {
        Draggable(content: self, snapBack: snapBack, onDragged: onDragged, onTapped: onTapped, onEnded: onEnded)
    }
    
    func onGeometryChange<Value>(compute: @escaping (GeometryProxy) -> Value, onChange: @escaping (Value) -> ()) -> some View where Value: Equatable {
        let key = TaggedKey<Value, ()>.self
        return self.overlay(GeometryReader { proxy in
            Color.clear.preference(key: key, value: compute(proxy))
        }).onPreferenceChange(key) { value in
            onChange(value!)
        }.preference(key: key, value: nil)
    }
}

struct ContentView: View {
    @State var cartItems: [(index: Int, anchor: Anchor<CGPoint>)] = []
    @State var dragRect: CGRect? = nil
    @State var dropRect: CGRect? = nil
    
    var body: some View {
        VStack {
            HStack {
                ForEach(0..<colors.count) { index in
                    ShoppingItem(index: index)
                        .draggable(snapBack: !self.isInDropZone, onDragged: {
                            self.dragRect = $0
                        }, onTapped: { anchor in
                            self.cartItems.append((index: index, anchor: anchor))
                        }, onEnded: { anchor in
                            guard self.isInDropZone else { return }
                            self.dragRect = nil
                            self.cartItems.append((index, anchor))
                        })
                }
            }.zIndex(1)
            Spacer()
            HStack {
                Spacer()
                ForEach(Array(self.cartItems.enumerated()), id: \.offset) { (ix, item) in
                    ShoppingItem(index: item.index)
                        .appearFrom(anchor: item.anchor)
                        .animation(.default)
                        .frame(width: 50, height: 50)
                        .transition(.identity)
                }
                Spacer()
            }.frame(height: 50)
                .padding()
                .background(Color(white: isInDropZone ? 0.7 : 0.5))
                .onGeometryChange(compute: { $0.frame(in: .global) }, onChange: { self.dropRect = $0 })
        }
    }
    
    var isInDropZone: Bool {
        guard let drag = dragRect, let drop = dropRect else { return false }
        return drag.intersects(drop)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
