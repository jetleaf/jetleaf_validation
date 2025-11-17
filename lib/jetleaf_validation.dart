// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
//
// This source file is part of the JetLeaf Framework and is protected
// under copyright law. You may not copy, modify, or distribute this file
// except in compliance with the JetLeaf license.
//
// For licensing terms, see the LICENSE file in the root of this project.
// ---------------------------------------------------------------------------
// 
// 🔧 Powered by Hapnium — the Dart backend engine 🍃

/// JetLeaf Validation Library 🍃
///
/// Provides the core validation framework for JetLeaf, enabling declarative,
/// annotation-driven constraint validation for fields, methods, and parameters.
///
/// This library integrates reflective metadata inspection, group-based validation,
/// and extensible constraint resolution via `@Constraint` and `@Validated`
/// annotations.
///
/// ### Key Features
/// - Declarative constraints using `@Constraint` annotations.
/// - Group-based validation via `@Validated` and `@Valid`.
/// - Built-in constraint validators (e.g. `@Size`, `@NotNull`, etc.).
/// - Reflection-backed validation context for runtime metadata access.
/// - Extensible factory configuration and auto-discovery.
///
/// ### Exports
/// - `annotations.dart` — Core validation annotations.
/// - `abstract_executable_validator.dart` — Base executable validator contract.
/// - `base.dart` — Shared validation utilities and foundational types.
/// - `constraint_validators.dart` — Built-in constraint validator implementations.
/// - `exceptions.dart` — Validation and constraint-related exception types.
/// - `validation_auto_configuration.dart` — Bootstrapping and auto-registration logic.
/// - `validation_factory.dart` — Main entry point for obtaining configured validators.
///
/// ### Example
/// ```dart
/// import 'package:jetleaf_validation/jetleaf_validation.dart';
///
/// final validator = ValidationFactory.create();
/// final report = validator.validate(user);
///
/// if (!report.isValid) {
///   report.violations.forEach(print);
/// }
/// ```
///
/// {@category JetLeaf Validation}
library;

export 'src/annotations.dart';
export 'src/abstract_executable_validator.dart';
export 'src/base.dart';
export 'src/constraint_validators.dart';
export 'src/exceptions.dart';
export 'src/validation_auto_configuration.dart';
export 'src/validation_factory.dart';