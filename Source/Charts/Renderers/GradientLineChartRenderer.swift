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
    
    open override func drawCubicBezier(context: CGContext, dataSet: ILineChartDataSet) {
        drawBezier(context: context, dataSet: dataSet)
    }

    open override func drawHorizontalBezier(context: CGContext, dataSet: ILineChartDataSet) {
        drawBezier(context: context, dataSet: dataSet)
    }

    open override func drawLinear(context: CGContext, dataSet: ILineChartDataSet) {
        drawBezier(context: context, dataSet: dataSet)
    }

    private func drawBezier(context: CGContext, dataSet: ILineChartDataSet) {
        context.saveGState()
        context.setLineCap(dataSet.lineCapType)
        drawGradientBezier(
            context: context,
            dataSet: dataSet
        )
        context.restoreGState()
    }
    
}

private extension GradientLineChartRenderer {
    
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
            
            for j in xBounds.dropFirst()
            {
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
        
        if dataSet.isDrawFilledEnabled {
            // Copy this path because we make changes to it
            let fillPath = cubicPath.mutableCopy()
            
            drawCubicFill(
                context: context,
                dataSet: dataSet,
                spline: fillPath!,
                matrix: valueToPixelMatrix,
                bounds: xBounds
            )
        }
        
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

        context.draw(gradientLayer, at: .zero)
        context.draw(chartLayer, at: .zero)
    }
    
}
