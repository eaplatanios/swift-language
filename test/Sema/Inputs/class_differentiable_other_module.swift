// SWIFT_ENABLE_TENSORFLOW

// expected-note @+1 {{type declared here}}
class OtherFileNonconforming {}

// expected-note @+1 {{type declared here}}
class GenericOtherFileNonconforming<T : Differentiable> {
  var x: T
}
