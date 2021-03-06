// SWIFT_ENABLE_TENSORFLOW
// RUN: %target-swift-frontend -typecheck -verify -primary-file %s %S/Inputs/class_differentiable_other_module.swift

// Verify that a `Differentiable` type upholds `AllDifferentiableVariables == TangentVector`.
func assertAllDifferentiableVariablesEqualsTangentVector<T>(_: T.Type)
  where T : Differentiable, T.AllDifferentiableVariables == T.TangentVector {}

// Verify that a type `T` conforms to `AdditiveArithmetic`.
func assertConformsToAdditiveArithmetic<T>(_: T.Type) where T : AdditiveArithmetic {}

// Verify that a type `T` conforms to `ElementaryFunctions`.
func assertConformsToElementaryFunctions<T>(_: T.Type) where T : ElementaryFunctions {}

// Verify that a type `T` conforms to `VectorProtocol`.
func assertConformsToVectorProtocol<T>(_: T.Type) where T : VectorProtocol {}

// Dummy protocol with default implementations for `AdditiveArithmetic` requirements.
// Used to test `Self : AdditiveArithmetic` requirements.
protocol DummyAdditiveArithmetic : AdditiveArithmetic {}
extension DummyAdditiveArithmetic {
  static func == (lhs: Self, rhs: Self) -> Bool {
    fatalError()
  }
  static var zero: Self {
    fatalError()
  }
  static func + (lhs: Self, rhs: Self) -> Self {
    fatalError()
  }
  static func - (lhs: Self, rhs: Self) -> Self {
    fatalError()
  }
}

class Empty : Differentiable {}
func testEmpty() {
  assertConformsToAdditiveArithmetic(Empty.AllDifferentiableVariables.self)
  assertConformsToAdditiveArithmetic(Empty.TangentVector.self)
  assertConformsToElementaryFunctions(Empty.AllDifferentiableVariables.self)
  assertConformsToElementaryFunctions(Empty.TangentVector.self)
}

// Test structs with `let` stored properties.
// Derived conformances fail because `mutating func move` requires all stored
// properties to be mutable.
class ImmutableStoredProperties : Differentiable {
  var okay: Float

  // expected-warning @+1 {{stored property 'nondiff' has no derivative because it does not conform to 'Differentiable'; add an explicit '@noDerivative' attribute}} {{3-3=@noDerivative }}
  let nondiff: Int

  // expected-warning @+1 {{synthesis of the 'Differentiable.move(along:)' requirement for 'ImmutableStoredProperties' requires all stored properties to be mutable; use 'var' instead, or add an explicit '@noDerivative' attribute}} {{3-3=@noDerivative }}
  let diff: Float

  init() {
    okay = 0
    nondiff = 0
    diff = 0
  }
}
func testImmutableStoredProperties() {
  _ = ImmutableStoredProperties.TangentVector(okay: 1)
}
class MutableStoredPropertiesWithInitialValue : Differentiable {
  var x = Float(1)
  var y = Double(1)
}
// Test class with both an empty constructor and memberwise initializer.
class AllMixedStoredPropertiesHaveInitialValue : Differentiable {
  let x = Float(1) // expected-warning {{synthesis of the 'Differentiable.move(along:)' requirement for 'AllMixedStoredPropertiesHaveInitialValue' requires all stored properties to be mutable; use 'var' instead, or add an explicit '@noDerivative' attribute}} {{3-3=@noDerivative }}
  var y = Float(1)
  // Memberwise initializer should be `init(y:)` since `x` is immutable.
  static func testMemberwiseInitializer() {
    _ = AllMixedStoredPropertiesHaveInitialValue()
  }
}
/*
class HasCustomConstructor: Differentiable {
  var x = Float(1)
  var y = Float(1)
  // Custom constructor should not affect synthesis.
  init(x: Float, y: Float, z: Bool) {}
}
*/

class Simple : Differentiable {
  var w: Float
  var b: Float

  init(w: Float, b: Float) {
    self.w = w
    self.b = b
  }
}
func testSimple() {
  let simple = Simple(w: 1, b: 1)
  let tangent = Simple.TangentVector(w: 1, b: 1)
  simple.move(along: tangent)
}

// Test type with mixed members.
class Mixed : Differentiable {
  var simple: Simple
  var float: Float

  init(simple: Simple, float: Float) {
    self.simple = simple
    self.float = float
  }
}
func testMixed(_ simple: Simple, _ simpleTangent: Simple.TangentVector) {
  let mixed = Mixed(simple: simple, float: 1)
  let tangent = Mixed.TangentVector(simple: simpleTangent, float: 1)
  mixed.move(along: tangent)
}

// Test type with manual definition of vector space types to `Self`.
final class VectorSpacesEqualSelf : Differentiable & DummyAdditiveArithmetic {
  var w: Float
  var b: Float
  typealias TangentVector = VectorSpacesEqualSelf
  typealias AllDifferentiableVariables = VectorSpacesEqualSelf

  init(w: Float, b: Float) {
    self.w = w
    self.b = b
  }
}
/*
extension VectorSpacesEqualSelf : Equatable, AdditiveArithmetic {
  static func == (lhs: VectorSpacesEqualSelf, rhs: VectorSpacesEqualSelf) -> Bool {
    fatalError()
  }
  static var zero: VectorSpacesEqualSelf {
    fatalError()
  }
  static func + (lhs: VectorSpacesEqualSelf, rhs: VectorSpacesEqualSelf) -> VectorSpacesEqualSelf {
    fatalError()
  }
  static func - (lhs: VectorSpacesEqualSelf, rhs: VectorSpacesEqualSelf) -> VectorSpacesEqualSelf {
    fatalError()
  }
}
*/

// Test generic type with vector space types to `Self`.
class GenericVectorSpacesEqualSelf<T> : Differentiable
  where T : Differentiable, T == T.TangentVector,
        T == T.AllDifferentiableVariables
{
  var w: T
  var b: T

  init(w: T, b: T) {
    self.w = w
    self.b = b
  }
}
func testGenericVectorSpacesEqualSelf() {
  let genericSame = GenericVectorSpacesEqualSelf<Double>(w: 1, b: 1)
  let tangent = GenericVectorSpacesEqualSelf.TangentVector(w: 1, b: 1)
  genericSame.move(along: tangent)
}

// Test nested type.
class Nested : Differentiable {
  var simple: Simple
  var mixed: Mixed
  var generic: GenericVectorSpacesEqualSelf<Double>

  init(simple: Simple, mixed: Mixed, generic: GenericVectorSpacesEqualSelf<Double>) {
    self.simple = simple
    self.mixed = mixed
    self.generic = generic
  }
}
func testNested(
  _ simple: Simple, _ mixed: Mixed,
  _ genericSame: GenericVectorSpacesEqualSelf<Double>
) {
  _ = Nested(simple: simple, mixed: mixed, generic: genericSame)
}

// Test type that does not conform to `AdditiveArithmetic` but whose members do.
// Thus, `Self` cannot be used as `TangentVector` or `TangentVector`.
// Vector space structs types must be synthesized.
// Note: it would be nice to emit a warning if conforming `Self` to
// `AdditiveArithmetic` is possible.
class AllMembersAdditiveArithmetic : Differentiable {
  var w: Float
  var b: Float

  init(w: Float, b: Float) {
    self.w = w
    self.b = b
  }
}
func testAllMembersAdditiveArithmetic() {
  assertAllDifferentiableVariablesEqualsTangentVector(AllMembersAdditiveArithmetic.self)
}

// Test type `AllMembersVectorProtocol` whose members conforms to `VectorProtocol`,
// in which case we should make `AllDifferentiableVariables` and `TangentVector`
// conform to `VectorProtocol`.
struct MyVector : VectorProtocol, Differentiable {
  var w: Float
  var b: Float

  init(w: Float, b: Float) {
    self.w = w
    self.b = b
  }
}
class AllMembersVectorProtocol : Differentiable {
  var v1: MyVector
  var v2: MyVector

  init(v: MyVector) {
    v1 = v
    v2 = v
  }
}
func testAllMembersVectorProtocol() {
  assertConformsToVectorProtocol(AllMembersVectorProtocol.AllDifferentiableVariables.self)
  assertConformsToVectorProtocol(AllMembersVectorProtocol.TangentVector.self)
}

// Test type `AllMembersElementaryFunctions` whose members conforms to `ElementaryFunctions`,
// in which case we should make `AllDifferentiableVariables` and `TangentVector`
// conform to `ElementaryFunctions`.
struct MyVector2 : ElementaryFunctions, Differentiable {
  var w: Float
  var b: Float

  init(w: Float, b: Float) {
    self.w = w
    self.b = b
  }
}
class AllMembersElementaryFunctions : Differentiable {
  var v1: MyVector2
  var v2: MyVector2

  init(v: MyVector2) {
    v1 = v
    v2 = v
  }
}
func testAllMembersElementaryFunctions() {
  assertConformsToElementaryFunctions(AllMembersElementaryFunctions.AllDifferentiableVariables.self)
  assertConformsToElementaryFunctions(AllMembersElementaryFunctions.TangentVector.self)
}

// Test type whose properties are not all differentiable.
class DifferentiableSubset : Differentiable {
  var w: Float
  var b: Float
  @noDerivative var flag: Bool
  @noDerivative let technicallyDifferentiable: Float = .pi

  init(w: Float, b: Float, flag: Bool) {
    self.w = w
    self.b = b
    self.flag = flag
  }
}
func testDifferentiableSubset() {
  assertConformsToAdditiveArithmetic(DifferentiableSubset.AllDifferentiableVariables.self)
  assertConformsToElementaryFunctions(DifferentiableSubset.AllDifferentiableVariables.self)
  assertConformsToVectorProtocol(DifferentiableSubset.AllDifferentiableVariables.self)
  assertAllDifferentiableVariablesEqualsTangentVector(DifferentiableSubset.self)
  _ = DifferentiableSubset.TangentVector(w: 1, b: 1)
  _ = DifferentiableSubset.TangentVector(w: 1, b: 1)
  _ = DifferentiableSubset.AllDifferentiableVariables(w: 1, b: 1)

  _ = pullback(at: DifferentiableSubset(w: 1, b: 2, flag: false)) { model in
    model.w + model.b
  }
}

// Test nested type whose properties are not all differentiable.
class NestedDifferentiableSubset : Differentiable {
  var x: DifferentiableSubset
  var mixed: Mixed
  @noDerivative var technicallyDifferentiable: Float

  init(x: DifferentiableSubset, mixed: Mixed) {
    self.x = x
    self.mixed = mixed
    technicallyDifferentiable = 0
  }
}
func testNestedDifferentiableSubset() {
  assertAllDifferentiableVariablesEqualsTangentVector(NestedDifferentiableSubset.self)
}

// Test type that uses synthesized vector space types but provides custom
// method.
class HasCustomMethod : Differentiable {
  var simple: Simple
  var mixed: Mixed
  var generic: GenericVectorSpacesEqualSelf<Double>

  init(simple: Simple, mixed: Mixed, generic: GenericVectorSpacesEqualSelf<Double>) {
    self.simple = simple
    self.mixed = mixed
    self.generic = generic
  }

  func move(along direction: TangentVector) {
    print("Hello world")
    simple.move(along: direction.simple)
    mixed.move(along: direction.mixed)
    generic.move(along: direction.generic)
  }
}

// Test type that conforms to `KeyPathIterable`.
// The `AllDifferentiableVariables` class should also conform to `KeyPathIterable`.
class TestKeyPathIterable : Differentiable, KeyPathIterable {
  var w: Float
  @noDerivative let technicallyDifferentiable: Float = .pi

  // NOTE: `KeyPathIterable` derived conformances do not yet support class
  // types.
  var allKeyPaths: [PartialKeyPath<TestKeyPathIterable>] {
    [\TestKeyPathIterable.w, \TestKeyPathIterable.technicallyDifferentiable]
  }

  init(w: Float) {
    self.w = w
    technicallyDifferentiable = 0
  }
}
func testKeyPathIterable(x: TestKeyPathIterable) {
  _ = x.allDifferentiableVariables.allKeyPaths
}

// Test type with user-defined memberwise initializer.
class TF_25: Differentiable {
  public var bar: Float
  public init(bar: Float) {
    self.bar = bar
  }
}
// Test user-defined memberwise initializer.
class TF_25_Generic<T : Differentiable>: Differentiable {
  public var bar: T
  public init(bar: T) {
    self.bar = bar
  }
}

// Test initializer that is not a memberwise initializer because of stored property name vs parameter label mismatch.
class HasCustomNonMemberwiseInitializer<T : Differentiable>: Differentiable {
  var value: T
  init(randomLabel value: T) { self.value = value }
}

// Test type with generic environment.
class HasGenericEnvironment<Scalar : FloatingPoint & Differentiable> : Differentiable {
  var x: Float = 0
}

// Test type with generic members that conform to `Differentiable`.
class GenericSynthesizeAllStructs<T : Differentiable> : Differentiable {
  var w: T
  var b: T

  init(w: T, b: T) {
    self.w = w
    self.b = b
  }
}

// Test type in generic context.
class A<T : Differentiable> {
  class B<U : Differentiable, V> : Differentiable {
    class InGenericContext : Differentiable {
      @noDerivative var a: A
      var b: B
      var t: T
      var u: U

      init(a: A, b: B, t: T, u: U) {
        self.a = a
        self.b = b
        self.t = t
        self.u = u
      }
    }
  }
}

// Test extension.
class Extended {
  var x: Float

  init(x: Float) {
    self.x = x
  }
}
extension Extended : Differentiable {}

// Test extension of generic type.
class GenericExtended<T> {
  var x: T

  init(x: T) {
    self.x = x
  }
}
extension GenericExtended : Differentiable where T : Differentiable {}

// Test constrained extension of generic type.
class GenericConstrained<T> {
  var x: T

  init(x: T) {
    self.x = x
  }
}
extension GenericConstrained : Differentiable
  where T : Differentiable {}

final class TF_260<T : Differentiable> : Differentiable & DummyAdditiveArithmetic {
  var x: T.TangentVector

  init(x: T.TangentVector) {
    self.x = x
  }
}

// TF-269: Test crash when differentiation properties have no getter.
// Related to access levels and associated type inference.

// TODO(TF-631): Blocked by class type differentiation support.
// [AD] Unhandled instruction in adjoint emitter:   %2 = ref_element_addr %0 : $TF_269, #TF_269.filter // user: %3
// [AD] Diagnosing non-differentiability.
// [AD] For instruction:
//   %2 = ref_element_addr %0 : $TF_269, #TF_269.filter // user: %3
/*
public protocol TF_269_Layer: Differentiable & KeyPathIterable
  where AllDifferentiableVariables: KeyPathIterable {

  associatedtype Input: Differentiable
  associatedtype Output: Differentiable
  func applied(to input: Input) -> Output
}

public class TF_269 : TF_269_Layer {
  public var filter: Float
  public typealias Activation = @differentiable (Output) -> Output
  @noDerivative public let activation: @differentiable (Output) -> Output

  init(filter: Float, activation: @escaping Activation) {
    self.filter = filter
    self.activation = activation
  }

  // NOTE: `KeyPathIterable` derived conformances do not yet support class
  // types.
  public var allKeyPaths: [PartialKeyPath<TF_269>] {
    []
  }

  public func applied(to input: Float) -> Float {
    return input
  }
}
*/

// Test errors.

// expected-error @+1 {{class 'MissingInitializer' has no initializers}}
class MissingInitializer : Differentiable {
  // expected-note @+1 {{stored property 'w' without initial value prevents synthesized initializers}}
  var w: Float
  // expected-note @+1 {{stored property 'b' without initial value prevents synthesized initializers}}
  var b: Float
}

// Test manually customizing vector space types.
// Thees should fail. Synthesis is semantically unsupported if vector space
// types are customized.
final class TangentVectorWB : DummyAdditiveArithmetic, Differentiable {
  var w: Float
  var b: Float

  init(w: Float, b: Float) {
    self.w = w
    self.b = b
  }
}
// expected-error @+2 {{type 'VectorSpaceTypeAlias' does not conform to protocol 'Differentiable'}}
// expected-note @+1 {{do you want to add protocol stubs?}}
final class VectorSpaceTypeAlias : DummyAdditiveArithmetic, Differentiable {
  var w: Float
  var b: Float
  typealias TangentVector = TangentVectorWB

  init(w: Float, b: Float) {
    self.w = w
    self.b = b
  }
}
// expected-error @+2 {{type 'VectorSpaceCustomStruct' does not conform to protocol 'Differentiable'}}
// expected-note @+1 {{do you want to add protocol stubs?}}
final class VectorSpaceCustomStruct : DummyAdditiveArithmetic, Differentiable {
  var w: Float
  var b: Float
  struct TangentVector : AdditiveArithmetic, Differentiable {
    var w: Float.TangentVector
    var b: Float.TangentVector
    typealias TangentVector = VectorSpaceCustomStruct.TangentVector
  }

  init(w: Float, b: Float) {
    self.w = w
    self.b = b
  }
}

class StaticNoDerivative : Differentiable {
  @noDerivative static var s: Bool = true // expected-error {{'@noDerivative' is only allowed on stored properties in structure or class types that declare a conformance to 'Differentiable'}}
}

final class StaticMembersShouldNotAffectAnything : DummyAdditiveArithmetic, Differentiable {
  static var x: Bool = true
  static var y: Bool = false
}

class ImplicitNoDerivative : Differentiable {
  var a: Float = 0
  var b: Bool = true // expected-warning {{stored property 'b' has no derivative because it does not conform to 'Differentiable'; add an explicit '@noDerivative' attribute}}
}

class ImplicitNoDerivativeWithSeparateTangent : Differentiable {
  var x: DifferentiableSubset
  var b: Bool = true // expected-warning {{stored property 'b' has no derivative because it does not conform to 'Differentiable'; add an explicit '@noDerivative' attribute}} {{3-3=@noDerivative }}

  init(x: DifferentiableSubset) {
    self.x = x
  }
}

// TF-265: Test invalid initializer (that uses a non-existent type).
class InvalidInitializer : Differentiable {
  init(filterShape: (Int, Int, Int, Int), blah: NonExistentType) {} // expected-error {{use of undeclared type 'NonExistentType'}}
}

// Test memberwise initializer synthesis.
final class NoMemberwiseInitializerExtended<T> {
  var value: T
  init(_ value: T) {
    self.value = value
  }
}
extension NoMemberwiseInitializerExtended: Equatable, AdditiveArithmetic, DummyAdditiveArithmetic
  where T : AdditiveArithmetic {}
extension NoMemberwiseInitializerExtended: Differentiable
  where T : Differentiable & AdditiveArithmetic {}

// Test derived conformances in disallowed contexts.

// expected-error @+4 {{type 'OtherFileNonconforming' does not conform to protocol 'Differentiable'}}
// expected-error @+3 {{implementation of 'Differentiable' cannot be automatically synthesized in an extension in a different file to the type}}
// expected-note @+2 {{do you want to add protocol stubs?}}
// expected-note @+1 {{do you want to add protocol stubs?}}
extension OtherFileNonconforming : Differentiable {}

// expected-error @+4 {{type 'GenericOtherFileNonconforming<T>' does not conform to protocol 'Differentiable'}}
// expected-error @+3 {{implementation of 'Differentiable' cannot be automatically synthesized in an extension in a different file to the type}}
// expected-note @+2 {{do you want to add protocol stubs?}}
// expected-note @+1 {{do you want to add protocol stubs?}}
extension GenericOtherFileNonconforming : Differentiable {}
