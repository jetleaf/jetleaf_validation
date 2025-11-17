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

import 'package:jetleaf_lang/lang.dart';

import 'base.dart';

/// {@template constraint_violation_exception}
/// Represents a **runtime exception** thrown when one or more constraint
/// violations are detected during validation.
///
/// This exception wraps a complete [ValidationReport] and provides
/// detailed introspection of all detected [ConstraintViolation]s.
///
/// ### Purpose
/// The `ConstraintViolationException` acts as the bridge between the
/// validation subsystem and runtime error handling. It allows developers
/// to programmatically inspect violations or produce human-readable summaries.
///
/// ### Key Features
/// - Encapsulates all violations via the [report].
/// - Provides a default, human-friendly error message summarizing the issues.
/// - Supports optional `message` and `cause` arguments for exception chaining.
/// - Extends [RuntimeException] for seamless integration with JetLeaf's
///   exception hierarchy.
///
/// ### Example
/// ```dart
/// try {
///   final report = validator.validate(user, user.getClass());
///   if (!report.isValid()) {
///     throw ConstraintViolationException(report);
///   }
/// } on ConstraintViolationException catch (e) {
///   print(e); // Pretty-printed list of violations
/// }
/// ```
///
/// ### Exception Behavior
/// - The constructor automatically generates a formatted violation summary
///   if no custom message is provided.
/// - The [toString] method overrides the base representation to include
///   violation summaries inline.
///
/// ### Integration Notes
/// - Used by interceptors like [AbstractValidationInterceptor] when validation
///   fails pre- or post-method execution.
/// - Should be caught in higher application layers (e.g., service or controller)
///   to transform validation errors into domain- or API-level responses.
///
/// ### See Also
/// - [ConstraintViolation]
/// - [ValidationReport]
/// - [DetailedConstraintViolation]
/// - [AbstractValidator]
/// - [RuntimeException]
/// {@endtemplate}
final class ConstraintViolationException extends RuntimeException {
  /// The validation report containing all detected constraint violations.
  ///
  /// Each violation entry provides information about the property path,
  /// invalid value, constraint message, and originating annotation or source.
  final ValidationReport report;

  /// {@macro constraint_violation_exception}
  ///
  /// Creates a new [ConstraintViolationException] from the provided [report].
  ///
  /// If no [message] is supplied, a formatted summary will be generated
  /// automatically from the contained [ConstraintViolation]s.
  ///
  /// ### Parameters
  /// - `report` – The validation report containing all constraint violations.
  /// - `message` – Optional custom message to override the auto-generated one.
  /// - `cause` – Optional underlying exception cause.
  ///
  /// ### Example
  /// ```dart
  /// throw ConstraintViolationException(report, cause: SomeOtherError());
  /// ```
  ConstraintViolationException(
    this.report, {
    String? message,
    Object? cause,
  }) : super(message ?? _defaultMessage(report), cause: cause);

  /// Builds a human-readable summary of all violations in the provided [report].
  ///
  /// Each violation is formatted in a multi-line structure, including:
  /// - Property path
  /// - Violation message
  /// - Invalid value
  /// - Source type
  ///
  /// Returns a fallback message if the report contains no violations.
  static String _defaultMessage(ValidationReport report) {
    if (report.isValid()) return 'Validation failed: no violations found.';

    final buffer = StringBuffer('Validation failed with the following violations:\n');
    for (final v in report.getViolations()) {
      buffer.writeln(
        ' • Property: "${v.getPropertyPath()}"\n'
        '   Message : ${v.getMessage()}\n'
        '   Invalid : ${v.getInvalidValue() ?? 'null'}\n'
        '   Source  : ${v.getSource().runtimeType}\n',
      );
    }
    return buffer.toString();
  }

  /// Returns all [ConstraintViolation] instances captured in the report.
  ///
  /// This provides direct access for inspection or serialization.
  ///
  /// ### Example
  /// ```dart
  /// for (final v in exception.allViolations) {
  ///   print('${v.getPropertyPath()}: ${v.getMessage()}');
  /// }
  /// ```
  Set<ConstraintViolation> get allViolations => report.getViolations();

  /// Returns a human-readable string representation of the exception,
  /// including a concise, one-line summary of all violations.
  ///
  /// ### Example Output
  /// ```
  /// ConstraintViolationException: Validation failed
  /// Violations: [email] must be a valid email; [age] must be >= 18
  /// ```
  @override
  String toString() {
    final summary = allViolations.isEmpty
        ? 'No constraint violations.'
        : allViolations
            .map((v) => '[${v.getPropertyPath()}] ${v.getMessage()}')
            .join('; ');

    final base = super.toString();
    return '$base\nViolations: $summary';
  }
}