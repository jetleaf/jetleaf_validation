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

import 'package:jetleaf_core/annotation.dart';

import 'validation_factory.dart';

/// {@template jetleaf_validation_auto_configuration}
/// JetLeaf **auto-configuration entry point** for the validation subsystem.
///
/// The [ValidationAutoConfiguration] class registers the default
/// [ValidationFactory] pod in the application context, making it available
/// for dependency injection and method-level validation interception.
///
/// This configuration is loaded automatically when the
/// `"jetleaf.validation.configuration"` profile is active, or when the
/// JetLeaf application context performs component scanning.
///
/// ### Purpose
/// - Provide a preconfigured instance of [ValidationFactory].
/// - Enable **annotation-driven validation** (e.g., `@Valid`, `@NotNull`,
///   `@InFuture`, etc.).
/// - Integrate the validation subsystem into the JetLeaf dependency
///   injection lifecycle.
///
/// ### Example
/// ```dart
/// @Configuration("jetleaf.validation.configuration")
/// final class ValidationAutoConfiguration {
///   const ValidationAutoConfiguration();
///
///   @Pod(value: "jetleaf.validation.factory")
///   ValidationFactory validationFactory() => ValidationFactory();
/// }
/// ```
///
/// ### Typical Usage
/// When included in the active application context:
/// ```dart
/// final context = JetLeafApplication.run();
/// final validator = context.getPod<ValidationFactory>("jetleaf.validation.factory");
///
/// final report = validator.validate(myObject);
/// if (!report.isValid()) {
///   print("Validation errors: ${report.getViolations()}");
/// }
/// ```
///
/// ### Pod Registration
/// The `@Pod` annotation declares a managed singleton under the name
/// `"jetleaf.validation.factory"`. This allows dependency injection into
/// other JetLeaf components, such as interceptors or services requiring
/// runtime validation.
///
/// ### Design Notes
/// - Serves as the **default entry point** for enabling validation.
/// - May be extended or replaced by custom validation configurations.
/// - Relies on JetLeaf’s [Configuration] and [Pod] annotations for
///   declarative pod registration.
///
/// ### See Also
/// - [ValidationFactory]
/// - [Configuration]
/// - [Pod]
/// - [ApplicationContext]
/// {@endtemplate}
@Configuration(ValidationAutoConfiguration.VALIDATION_AUTO_CONFIGURATION_POD_NAME)
final class ValidationAutoConfiguration {
  /// {@macro jetleaf_validation_auto_configuration}
  const ValidationAutoConfiguration();

  /// Pod name for the **ValidationAutoConfiguration**.
  ///
  /// Configures the Jetleaf validation framework, integrating
  /// annotation-based constraint validation.
  static const String VALIDATION_AUTO_CONFIGURATION_POD_NAME = "jetleaf.validation.configuration";

  /// Pod name for the **ValidationFactory**.
  ///
  /// Provides a factory for creating and managing validator instances
  /// that enforce annotated constraints on pods and request data.
  static const String VALIDATION_FACTORY_POD_NAME = "jetleaf.validation.factory";

  /// Declares and exposes the default [ValidationFactory] pod.
  ///
  /// Registered under the identifier [VALIDATION_FACTORY_POD_NAME],
  /// this factory provides validation and interception capabilities
  /// for annotated pods and methods.
  @Pod(value: VALIDATION_FACTORY_POD_NAME)
  ValidationFactory validationFactory() => ValidationFactory();
}