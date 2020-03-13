//
//  GradientLineChartView.swift
//  Charts
//
//  Created by v.rusinov on 11/03/2020.
//

import UIKit
import Foundation
import CoreGraphics

/// Chart that draws gradient lines
open class GradientLineChartView: LineChartView {
    
    // MARK: - Private variables
    
    private let startColor: UIColor
    private let endColor: UIColor
    private let fillColor: UIColor
    private var multipleHighlightsGestureRecognizer: MultipleHighlightsGestureRecognizer!
    
    // MARK: - Initializers
    
    public init(startColor: UIColor,
         endColor: UIColor,
         fillColor: UIColor) {
        self.startColor = startColor
        self.endColor = endColor
        self.fillColor = fillColor
        super.init(frame: .zero)
        self.initialize()
    }
    
    @available(iOS, unavailable)
    public override init(frame: CGRect) {
        self.startColor = .red
        self.endColor = .green
        self.fillColor = .white
        super.init(frame: frame)
        initialize()
    }
    
    @available(iOS, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        self.startColor = .red
        self.endColor = .green
        self.fillColor = .white
        super.init(coder: aDecoder)
        initialize()
    }
    
    // MARK: - Override functions
    
    internal override func initialize() {
        #if os(iOS)
        self.backgroundColor = NSUIColor.clear
        #endif
        
        _animator = Animator()
        _animator.delegate = self
        
        _viewPortHandler = ViewPortHandler(width: bounds.size.width, height: bounds.size.height)
        
        chartDescription = Description()
        
        _legend = Legend()
        _legendRenderer = LegendRenderer(viewPortHandler: _viewPortHandler, legend: _legend)
        
        _xAxis = XAxis()
        
        addObserver(self, forKeyPath: "bounds", options: .new, context: nil)
        addObserver(self, forKeyPath: "frame", options: .new, context: nil)
        
        _leftAxisTransformer = Transformer(viewPortHandler: _viewPortHandler)
        _rightAxisTransformer = Transformer(viewPortHandler: _viewPortHandler)
        
        highlighter = ChartHighlighter(chart: self)
        
        addMultipleHighlightsGesture()
        renderer = GradientLineChartRenderer(
            dataProvider: self,
            animator: _animator,
            viewPortHandler: _viewPortHandler,
            startColor: startColor,
            endColor: endColor,
            fillColor: fillColor
        )
    }
    
    open override func setScaleEnabled(_ enabled: Bool) { }
    
}

// MARK: - Custom gesture

extension GradientLineChartView {
    
    func addMultipleHighlightsGesture() {
        multipleHighlightsGestureRecognizer = MultipleHighlightsGestureRecognizer(
            target: self,
            action: #selector(processSelectionGesture(_:))
        )
        multipleHighlightsGestureRecognizer.delegate = self
        
        addGestureRecognizer(multipleHighlightsGestureRecognizer)
    }
    
    @objc
    func processSelectionGesture(_ recognizer: MultipleHighlightsGestureRecognizer) {
        switch recognizer.state {
        case .began:
            fallthrough
        case .changed:
            self.handleSelection(recognizer: recognizer)
        case .cancelled, .ended, .failed, .possible:
            lastHighlighted = nil
            highlightValue(nil, callDelegate: false)
            delegate?.chartViewDidEndPanning?(self)
        @unknown default:
            break
        }
    }
    
    private func handleSelection(recognizer: MultipleHighlightsGestureRecognizer) {
        switch recognizer.gestureType {
        case .noTouch:
            lastHighlighted = nil
            highlightValue(nil, callDelegate: false)
        case .oneTouch(let touch):
            if let h = getHighlightByTouchPoint(touch.location(in: self)) {
                lastHighlighted = h
                highlightValue(h, callDelegate: true)
            }
        case let .twoTouches(first, second):
            guard
                let highlight1 = getHighlightByTouchPoint(first.location(in: self)),
                let highlight2 = getHighlightByTouchPoint(second.location(in: self))
                else {
                    return
            }
            
            if highlight1.x == highlight2.x {
                lastHighlighted = highlight1
                highlightValue(highlight1, callDelegate: true)
            } else {
                lastHighlighted = highlight1
                highlightValues([highlight1, highlight2], callDelegate: true)
            }
        }
    }
}
    
    
// MARK: - Draw
    
extension GradientLineChartView {
    
    open override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard data != nil, let renderer = renderer else { return }
        
        let optionalContext = NSUIGraphicsGetCurrentContext()
        guard let context = optionalContext else { return }

        // execute all drawing commands
        drawGridBackground(context: context)

        if leftAxis.isEnabled {
            leftYAxisRenderer.computeAxis(min: leftAxis._axisMinimum, max: leftAxis._axisMaximum, inverted: leftAxis.isInverted)
        }
        
        if rightAxis.isEnabled {
            rightYAxisRenderer.computeAxis(min: rightAxis._axisMinimum, max: rightAxis._axisMaximum, inverted: rightAxis.isInverted)
        }
        
        if _xAxis.isEnabled {
            xAxisRenderer.computeAxis(min: _xAxis._axisMinimum, max: _xAxis._axisMaximum, inverted: false)
        }
        
        xAxisRenderer.renderAxisLine(context: context)
        leftYAxisRenderer.renderAxisLine(context: context)
        rightYAxisRenderer.renderAxisLine(context: context)
        
        context.saveGState()
        // make sure the data cannot be drawn outside the content-rect
        if clipDataToContentEnabled {
            context.clip(to: _viewPortHandler.contentRect)
        }
        renderer.drawData(context: context)
        
        // The renderers are responsible for clipping, to account for line-width center etc.
        if !xAxis.drawGridLinesBehindDataEnabled {
            xAxisRenderer.renderGridLines(context: context)
            leftYAxisRenderer.renderGridLines(context: context)
            rightYAxisRenderer.renderGridLines(context: context)
        }
        
        // if highlighting is enabled
        if (valuesToHighlight()) {
            renderer.drawHighlighted(context: context, indices: _indicesToHighlight)
        }
        
        context.restoreGState()
        
        renderer.drawExtras(context: context)
        
        if _xAxis.isEnabled && !_xAxis.isDrawLimitLinesBehindDataEnabled {
            xAxisRenderer.renderLimitLines(context: context)
        }
        
        if leftAxis.isEnabled && !leftAxis.isDrawLimitLinesBehindDataEnabled {
            leftYAxisRenderer.renderLimitLines(context: context)
        }
        
        if rightAxis.isEnabled && !rightAxis.isDrawLimitLinesBehindDataEnabled {
            rightYAxisRenderer.renderLimitLines(context: context)
        }
        
        xAxisRenderer.renderAxisLabels(context: context)
        leftYAxisRenderer.renderAxisLabels(context: context)
        rightYAxisRenderer.renderAxisLabels(context: context)

        if clipValuesToContentEnabled {
            context.saveGState()
            context.clip(to: _viewPortHandler.contentRect)
            
            renderer.drawValues(context: context)
            
            context.restoreGState()
        } else {
            renderer.drawValues(context: context)
        }

        _legendRenderer.renderLegend(context: context)

        drawDescription(context: context)
        
        drawMarkers(context: context)
        
        // The renderers are responsible for clipping, to account for line-width center etc.
        if xAxis.drawGridLinesBehindDataEnabled {
            xAxisRenderer.renderGridLines(context: context)
            leftYAxisRenderer.renderGridLines(context: context)
            rightYAxisRenderer.renderGridLines(context: context)
        }
        
        if _xAxis.isEnabled && _xAxis.isDrawLimitLinesBehindDataEnabled {
            xAxisRenderer.renderLimitLines(context: context)
        }
        
        if leftAxis.isEnabled && leftAxis.isDrawLimitLinesBehindDataEnabled {
            leftYAxisRenderer.renderLimitLines(context: context)
        }
        
        if rightAxis.isEnabled && rightAxis.isDrawLimitLinesBehindDataEnabled {
            rightYAxisRenderer.renderLimitLines(context: context)
        }
    }

}
