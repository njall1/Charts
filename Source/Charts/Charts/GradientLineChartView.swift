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
    
    internal override func initialize() {
        super.initialize()
         
        renderer = GradientLineChartRenderer(
            dataProvider: self,
            animator: _animator,
            viewPortHandler: _viewPortHandler,
            startColor: startColor,
            endColor: endColor,
            fillColor: fillColor
        )
    }
    
    open override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard data != nil, let renderer = renderer else { return }
        
        let optionalContext = NSUIGraphicsGetCurrentContext()
        guard let context = optionalContext else { return }

        // execute all drawing commands
        drawGridBackground(context: context)

        if leftAxis.isEnabled
        {
            leftYAxisRenderer.computeAxis(min: leftAxis._axisMinimum, max: leftAxis._axisMaximum, inverted: leftAxis.isInverted)
        }
        
        if rightAxis.isEnabled
        {
            rightYAxisRenderer.computeAxis(min: rightAxis._axisMinimum, max: rightAxis._axisMaximum, inverted: rightAxis.isInverted)
        }
        
        if _xAxis.isEnabled
        {
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
        if !xAxis.drawGridLinesBehindDataEnabled
        {
            xAxisRenderer.renderGridLines(context: context)
            leftYAxisRenderer.renderGridLines(context: context)
            rightYAxisRenderer.renderGridLines(context: context)
        }
        
        // if highlighting is enabled
        if (valuesToHighlight())
        {
            renderer.drawHighlighted(context: context, indices: _indicesToHighlight)
        }
        
        context.restoreGState()
        
        renderer.drawExtras(context: context)
        
        if _xAxis.isEnabled && !_xAxis.isDrawLimitLinesBehindDataEnabled
        {
            xAxisRenderer.renderLimitLines(context: context)
        }
        
        if leftAxis.isEnabled && !leftAxis.isDrawLimitLinesBehindDataEnabled
        {
            leftYAxisRenderer.renderLimitLines(context: context)
        }
        
        if rightAxis.isEnabled && !rightAxis.isDrawLimitLinesBehindDataEnabled
        {
            rightYAxisRenderer.renderLimitLines(context: context)
        }
        
        xAxisRenderer.renderAxisLabels(context: context)
        leftYAxisRenderer.renderAxisLabels(context: context)
        rightYAxisRenderer.renderAxisLabels(context: context)

        if clipValuesToContentEnabled
        {
            context.saveGState()
            context.clip(to: _viewPortHandler.contentRect)
            
            renderer.drawValues(context: context)
            
            context.restoreGState()
        }
        else
        {
            renderer.drawValues(context: context)
        }

        _legendRenderer.renderLegend(context: context)

        drawDescription(context: context)
        
        drawMarkers(context: context)
        
        // The renderers are responsible for clipping, to account for line-width center etc.
        if xAxis.drawGridLinesBehindDataEnabled
        {
            xAxisRenderer.renderGridLines(context: context)
            leftYAxisRenderer.renderGridLines(context: context)
            rightYAxisRenderer.renderGridLines(context: context)
        }
        
        if _xAxis.isEnabled && _xAxis.isDrawLimitLinesBehindDataEnabled
        {
            xAxisRenderer.renderLimitLines(context: context)
        }
        
        if leftAxis.isEnabled && leftAxis.isDrawLimitLinesBehindDataEnabled
        {
            leftYAxisRenderer.renderLimitLines(context: context)
        }
        
        if rightAxis.isEnabled && rightAxis.isDrawLimitLinesBehindDataEnabled
        {
            rightYAxisRenderer.renderLimitLines(context: context)
        }
    }
    
}
