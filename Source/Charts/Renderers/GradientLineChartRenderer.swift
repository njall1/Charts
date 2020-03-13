//
//  GradientLineChartRenderer.swift
//  Charts
//
//  Created by v.rusinov on 11/03/2020.
//

import UIKit
import Foundation
import CoreGraphics

open class GradientLineChartRenderer: LineChartRenderer {
    
    init(dataProvider: LineChartDataProvider,
         animator: Animator,
         viewPortHandler: ViewPortHandler,
         startColor: UIColor,
         endColor: UIColor,
         fillColor: UIColor) {
        
        self.startColor = startColor
        self.endColor = endColor
        self.fillColor = fillColor
        
        super.init(
            dataProvider:
            dataProvider,
            animator: animator,
            viewPortHandler: viewPortHandler
        )
    }
    
    private var startColor: UIColor
    private var endColor: UIColor
    private var fillColor: UIColor
    private var xBounds = XBounds()
    
    private var chartLayer: CGLayer?
    
    open override func drawCubicBezier(context: CGContext, dataSet: ILineChartDataSet) {
        drawBezier(context: context, dataSet: dataSet)
    }

    open override func drawHorizontalBezier(context: CGContext, dataSet: ILineChartDataSet) {
        drawBezier(context: context, dataSet: dataSet)
    }

    open override func drawLinear(context: CGContext, dataSet: ILineChartDataSet) {
        drawBezier(context: context, dataSet: dataSet)
    }
    
    open override func drawHighlighted(context: CGContext, indices: [Highlight]) {
        super.drawHighlighted(context: context, indices: indices)
        
        guard
            indices.count > 1,
            let size = (dataProvider as? LineChartView)?.bounds.size,
            let fillLayer = self.chartLayer,
            let fillLayerContext = fillLayer.context
        else {
            return
        }
        
        let leftHighlight = indices[0].drawX < indices[1].drawX ? indices[0] : indices[1]
        let rightHighlight = indices[1].drawX > indices[0].drawX ? indices[1] : indices[0]
        let fillWidth = abs(rightHighlight.drawX - leftHighlight.drawX)
        
        context.saveGState()
        context.clip()
        context.setFillColor(endColor.cgColor)
        context.setAlpha(0.05)
        context.fill(CGRect(
            x: leftHighlight.drawX,
            y: 0,
            width: fillWidth,
            height: fillLayer.size.height)
        )
        context.restoreGState()
    }
    
}

private extension GradientLineChartRenderer {
    
    func drawBezier(context: CGContext, dataSet: ILineChartDataSet) {
        context.saveGState()
        context.setLineCap(dataSet.lineCapType)
        drawGradientBezier(
            context: context,
            dataSet: dataSet
        )
        context.restoreGState()
    }
    
    func makePath(context: CGContext,
                  dataSet: ILineChartDataSet,
                  size: CGSize) -> CGPath? {
        guard let dataProvider = dataProvider else { return  nil }
        
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        let phaseY = animator.phaseY
        
        xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
        
        // the path for the cubic-spline
        let cubicPath = CGMutablePath()
        
        let valueToPixelMatrix = trans.valueToPixelMatrix
        
        if xBounds.range >= 1 {
            var prev: ChartDataEntry! = dataSet.entryForIndex(xBounds.min)
            var cur: ChartDataEntry! = prev
            
            if cur == nil { return nil }
            
            // let the spline start
            cubicPath.move(to: CGPoint(x: CGFloat(cur.x), y: CGFloat(cur.y * phaseY)), transform: valueToPixelMatrix)
            
            for j in xBounds.dropFirst() {
                prev = cur
                cur = dataSet.entryForIndex(j)
                
                let cpx = CGFloat(prev.x + (cur.x - prev.x) / 2.0)
                
                cubicPath.addCurve(
                    to: CGPoint(
                        x: CGFloat(cur.x),
                        y: CGFloat(cur.y * phaseY)),
                    control1: CGPoint(
                        x: cpx,
                        y: CGFloat(prev.y * phaseY)),
                    control2: CGPoint(
                        x: cpx,
                        y: CGFloat(cur.y * phaseY)),
                    transform: valueToPixelMatrix)
            }
        }
        
        context.saveGState()
        
        return cubicPath
    }
    
    func makeChartLayer(context: CGContext,
                        dataSet: ILineChartDataSet,
                        rect: CGRect) -> CGLayer? {
        guard
            let chartLayer = CGLayer(context, size: rect.size, auxiliaryInfo: nil),
            let chartLayerContext = chartLayer.context,
            let cubicPath = makePath(context: context, dataSet: dataSet, size: rect.size)
        else {
            return nil
        }
        
        chartLayerContext.setFillColor(fillColor.cgColor)
        chartLayerContext.fill(rect)
        
        chartLayerContext.beginPath()
        chartLayerContext.addPath(cubicPath)
        chartLayerContext.setStrokeColor(UIColor.black.cgColor)
        chartLayerContext.setLineWidth(dataSet.lineWidth)
        chartLayerContext.setBlendMode(.clear)
        chartLayerContext.strokePath()
        
        return chartLayer
    }
    
    func makeGradientLayer(startColor: UIColor,
                           endColor: UIColor,
                           context: CGContext,
                           size: CGSize) -> CGLayer? {
        guard
            let gradientLayer = CGLayer(context, size: size, auxiliaryInfo: nil),
            let gradientLayerContext = gradientLayer.context
        else {
            return  nil
        }
        
        let colors = [startColor.cgColor, endColor.cgColor]
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let colorLocations: [CGFloat] = [0.0, 1.0]
        
        let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors as CFArray,
            locations: colorLocations
        )!
        
        let startPoint = CGPoint.zero
        let endPoint = CGPoint(x: 0, y: size.height)
        
        gradientLayerContext.drawLinearGradient(
            gradient,
            start: startPoint,
            end: endPoint,
            options: []
        )
        
        return gradientLayer
    }
    
    func drawGradientBezier(context: CGContext, dataSet: ILineChartDataSet) {
        guard
            let chart = dataProvider as? LineChartView,
            let gradientLayer = makeGradientLayer(
                startColor: startColor,
                endColor: endColor,
                context: context,
                size: chart.bounds.size
            ),
            let chartLayer = makeChartLayer(
                context: context,
                dataSet: dataSet,
                rect: chart.frame
            )
        else {
            return
        }
        
        self.chartLayer = chartLayer

        context.draw(gradientLayer, at: .zero)
        context.draw(chartLayer, at: .zero)
    }
    
}
