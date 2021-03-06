//===--- DifferentiationUnittest.swift ------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

public enum _GlobalLeakCount {
  public static var count = 0
}

/// A type that tracks the number of live instances of a wrapped value type.
///
/// `Tracked<T>` is used to check for memory leaks in functions created via
/// automatic differentiation.
public struct Tracked<T> {
  fileprivate class Box {
    fileprivate var value : T
    init(_ value: T) {
      self.value = value
      _GlobalLeakCount.count += 1
    }
    deinit {
      _GlobalLeakCount.count -= 1
    }
  }
  private var handle: Box

  @differentiable(
    vjp: _vjpInit
    where T : Differentiable, T == T.AllDifferentiableVariables,
          T == T.TangentVector
  )
  public init(_ value: T) {
    self.handle = Box(value)
  }

  @differentiable(
    vjp: _vjpValue
    where T : Differentiable, T == T.AllDifferentiableVariables,
          T == T.TangentVector
  )
  public var value: T {
    get { handle.value }
    set { handle.value = newValue }
  }
}

extension Tracked : ExpressibleByFloatLiteral where T : ExpressibleByFloatLiteral {
  public init(floatLiteral value: T.FloatLiteralType) {
    self.handle = Box(T(floatLiteral: value))
  }
}

extension Tracked : CustomStringConvertible {
  public var description: String { return "Tracked(\(value))" }
}

extension Tracked : ExpressibleByIntegerLiteral where T : ExpressibleByIntegerLiteral {
  public init(integerLiteral value: T.IntegerLiteralType) {
    self.handle = Box(T(integerLiteral: value))
  }
}

extension Tracked : Comparable where T : Comparable {
  public static func < (lhs: Tracked, rhs: Tracked) -> Bool {
    return lhs.value < rhs.value
  }
  public static func <= (lhs: Tracked, rhs: Tracked) -> Bool {
    return lhs.value <= rhs.value
  }
  public static func > (lhs: Tracked, rhs: Tracked) -> Bool {
    return lhs.value > rhs.value
  }
  public static func >= (lhs: Tracked, rhs: Tracked) -> Bool {
    return lhs.value >= rhs.value
  }
}

extension Tracked : AdditiveArithmetic where T : AdditiveArithmetic {
  public static var zero: Tracked { return Tracked(T.zero) }
  public static func + (lhs: Tracked, rhs: Tracked) -> Tracked {
    return Tracked(lhs.value + rhs.value)
  }
  public static func - (lhs: Tracked, rhs: Tracked) -> Tracked {
    return Tracked(lhs.value - rhs.value)
  }
}

extension Tracked : Equatable where T : Equatable {
  public static func == (lhs: Tracked, rhs: Tracked) -> Bool {
    return lhs.value == rhs.value
  }
}

extension Tracked : SignedNumeric & Numeric where T : SignedNumeric, T == T.Magnitude {
  public typealias Magnitude = Tracked<T.Magnitude>

  public init?<U>(exactly source: U) where U : BinaryInteger {
    if let t = T(exactly: source) {
      self.init(t)
    }
    return nil
  }
  public var magnitude: Magnitude { return Magnitude(value.magnitude) }

  public static func * (lhs: Tracked, rhs: Tracked) -> Tracked {
    return Tracked(lhs.value * rhs.value)
  }

  public static func *= (lhs: inout Tracked, rhs: Tracked) {
    lhs = lhs * rhs
  }
}

extension Tracked where T : FloatingPoint {
  public static func / (lhs: Tracked, rhs: Tracked) -> Tracked {
    return Tracked(lhs.value / rhs.value)
  }

  public static func /= (lhs: inout Tracked, rhs: Tracked) {
    lhs = lhs / rhs
  }
}

extension Tracked : Strideable where T : Strideable, T.Stride == T.Stride.Magnitude {
  public typealias Stride = Tracked<T.Stride>

  public func distance(to other: Tracked) -> Stride {
    return Stride(value.distance(to: other.value))
  }
  public func advanced(by n: Stride) -> Tracked {
    return Tracked(value.advanced(by: n.value))
  }
}

// For now, `T` must be restricted to trivial types (like `Float` or `Tensor`).
extension Tracked : Differentiable
  where T : Differentiable, T == T.AllDifferentiableVariables,
        T == T.TangentVector
{
  public typealias AllDifferentiableVariables = Tracked<T.AllDifferentiableVariables>
  public typealias TangentVector = Tracked<T.TangentVector>
}

extension Tracked where T : Differentiable, T == T.AllDifferentiableVariables,
                        T == T.TangentVector
{
  // FIXME(TF-667): VJPs of initializers are currently not being reabstracted,
  // while there is a parameter convention mismatch. We must explicitly make
  // VJPs of initializers have `@owned` parameters to avoid memory leaks.
  @usableFromInline
  internal static func _vjpInit(_ value: __owned T)
      -> (value: Self, pullback: (Self.TangentVector) -> (T.TangentVector)) {
    return (Tracked(value), { v in v.value })
  }

  @usableFromInline
  internal func _vjpValue() -> (T, (T.TangentVector) -> Self.TangentVector) {
    return (value, { v in Tracked(v) })
  }
}

extension Tracked where T : Differentiable, T == T.AllDifferentiableVariables,
                        T == T.TangentVector
{
  @usableFromInline
  @differentiating(+)
  internal static func _vjpAdd(lhs: Self, rhs: Self)
      -> (value: Self, pullback: (Self) -> (Self, Self)) {
    return (lhs + rhs, { v in (v, v) })
  }

  @usableFromInline
  @differentiating(-)
  internal static func _vjpSubtract(lhs: Self, rhs: Self)
      -> (value: Self, pullback: (Self) -> (Self, Self)) {
    return (lhs - rhs, { v in (v, .zero - v) })
  }
}

extension Tracked where T : Differentiable & SignedNumeric, T == T.Magnitude,
                        T == T.AllDifferentiableVariables, T == T.TangentVector {
  @usableFromInline
  @differentiating(*)
  internal static func _vjpMultiply(lhs: Self, rhs: Self)
      -> (value: Self, pullback: (Self) -> (Self, Self)) {
    return (lhs * rhs, { v in (v * rhs, v * lhs) })
  }
}

extension Tracked where T : Differentiable & FloatingPoint,
                        T == T.AllDifferentiableVariables, T == T.TangentVector {
  @usableFromInline
  @differentiating(/)
  internal static func _vjpDivide(lhs: Self, rhs: Self)
      -> (value: Self, pullback: (Self) -> (Self, Self)) {
    return (lhs / rhs, { v in (v / rhs, -lhs / (rhs * rhs) * v) })
  }
}

// Differential operators for `Tracked<Float>`.
public extension Differentiable {
  @inlinable
  func gradient(
    in f: @differentiable (Self) -> Tracked<Float>
  ) -> TangentVector {
    return self.pullback(in: f)(1)
  }

  @inlinable
  func gradient<T : Differentiable>(
    at x: T, in f: @differentiable (Self, T) -> Tracked<Float>
  ) -> (TangentVector, T.TangentVector) {
    return self.pullback(at: x, in: f)(1)
  }

  @inlinable
  func valueWithGradient(
    in f: @differentiable (Self) -> Tracked<Float>
  ) -> (value: Tracked<Float>, gradient: TangentVector) {
    let (y, pb) = self.valueWithPullback(in: f)
    return (y, pb(1))
  }

  @inlinable
  func valueWithGradient<T : Differentiable>(
    at x: T, in f: @differentiable (Self, T) -> Tracked<Float>
  ) -> (value: Tracked<Float>, gradient: (TangentVector, T.TangentVector)) {
    let (y, pb) = self.valueWithPullback(at: x, in: f)
    return (y, pb(1))
  }
}
