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

import 'package:jetleaf_env/env.dart';
import 'package:jetleaf_lang/lang.dart';

import 'annotations.dart';
import 'base.dart';

/// {@template detailed_constraint_violation}
/// A rich, immutable representation of a single validation failure within
/// JetLeaf’s constraint validation subsystem.
///
/// This class provides a detailed context about a constraint violation that
/// occurred during runtime validation of annotated classes, methods, or
/// properties. Each instance captures the full metadata necessary for
/// diagnostics, error reporting, or programmatic resolution.
///
/// ### Overview
/// A `DetailedConstraintViolation` describes:
/// - **What** failed (via [propertyPath] and [invalidValue])
/// - **Why** it failed (via [message] and [constraintAnnotation])
/// - **Where** it was validated (via [source])
/// - **Under which conditions** (via [groups] and [payloads])
///
/// JetLeaf validators generate instances of this class when a constraint
/// (such as `@NotNull`, `@Size`, or `@Email`) is not satisfied. These are then
/// aggregated into a [ValidationReport].
///
/// ### Immutability
/// All fields are `final`, ensuring that a violation is a stable snapshot of
/// validation state at the time of failure.
///
/// ### Usage
/// ```dart
/// final violation = DetailedConstraintViolation(
///   propertyPath: 'email',
///   invalidValue: 'invalid@',
///   source: Source.field,
///   message: 'must be a well-formed email address',
///   constraintAnnotation: Email(),
///   groups: {DefaultGroup},
///   payloads: {},
/// );
///
/// print(violation.getMessage());
/// // → "must be a well-formed email address"
/// ```
///
/// ### Notes
/// - Property paths follow dot notation for nested structures (e.g. `address.street`).
/// - The `invalidValue` is captured *as-is* for debugging; it may be `null`.
/// - `constraintAnnotation` references the annotation instance that defined
///   the violated rule, allowing advanced reflection or serialization.
///
/// ### See Also
/// - [ConstraintViolation] — the contract implemented by this class.
/// - [SimpleValidationReport] — aggregates violations.
/// - [ConstraintValidator] — produces violations.
/// {@endtemplate}
final class DetailedConstraintViolation implements ConstraintViolation {
  /// Dot-notation path identifying the property or element that failed validation.
  ///
  /// For example:
  /// - `"email"` for a field constraint.
  /// - `"user.address.city"` for nested object validation.
  final String propertyPath;

  /// The runtime value that caused the violation.
  ///
  /// May be `null` if the violation relates to a missing or optional field.
  final Object? invalidValue;

  /// The logical source of the validated element.
  ///
  /// Indicates whether validation was triggered on a constructor parameter,
  /// method parameter, return value, or object field.
  final Source source;

  /// Human-readable message describing the failure.
  ///
  /// Typically derived from the constraint’s `message` attribute, possibly
  /// interpolated with runtime values.
  final String message;

  /// The constraint annotation instance responsible for this violation.
  ///
  /// Enables frameworks and diagnostic tools to inspect metadata such as
  /// severity, category, or custom attributes defined on the annotation.
  final ReflectableAnnotation constraintAnnotation;

  /// The active validation groups when this violation occurred.
  ///
  /// Validation groups are used to partition rules by context (e.g. default,
  /// creation, update).
  final Set<Class> groups;

  /// Optional metadata payloads attached to the constraint.
  ///
  /// Payloads allow custom extensions (e.g. severity levels, codes) without
  /// changing the base constraint interface.
  final Set<ConstraintPayload> payloads;

  /// Creates an immutable [DetailedConstraintViolation].
  /// 
  /// {@macro detailed_constraint_violation}
  const DetailedConstraintViolation({
    required this.propertyPath,
    required this.invalidValue,
    required this.source,
    required this.message,
    required this.constraintAnnotation,
    required this.groups,
    required this.payloads,
  });

  @override
  String getPropertyPath() => propertyPath;

  @override
  Object? getInvalidValue() => invalidValue;

  @override
  Source getSource() => source;

  @override
  String getMessage() => message;

  @override
  ReflectableAnnotation getConstraintAnnotation() => constraintAnnotation;

  @override
  Set<Class> getGroups() => groups;

  @override
  Set<ConstraintPayload> getPayloads() => payloads;

  @override
  List<Object?> equalizedProperties() => [payloads, constraintAnnotation, groups, source, message, invalidValue, propertyPath];
}

/// {@template simple_validation_report}
/// Minimal, immutable implementation of the [ValidationReport] interface.
///
/// A [SimpleValidationReport] aggregates multiple [ConstraintViolation]s into
/// a single result object that represents the outcome of a validation operation.
///
/// ### Behavior
/// - `isValid()` — returns `true` if there are no constraint violations.
/// - `getViolations()` — returns the full, immutable set of violations.
/// - `getViolationsForProperty(path)` — filters violations by property path.
/// - `getFirstViolationMessage()` — returns the message of the first violation,
///   or `null` if none exist.
///
/// ### Use Cases
/// The class serves as a convenient default when no advanced reporting features
/// (e.g., localization, categorization, merging) are required.
///
/// ```dart
/// final violations = {
///   DetailedConstraintViolation(
///     propertyPath: 'age',
///     invalidValue: -1,
///     source: Source.field,
///     message: 'must be greater than or equal to 0',
///     constraintAnnotation: Min(0),
///     groups: {DefaultGroup},
///     payloads: {},
///   )
/// };
///
/// final report = SimpleValidationReport(violations);
///
/// if (!report.isValid()) {
///   print(report.getFirstViolationMessage());
///   // → "must be greater than or equal to 0"
/// }
/// ```
///
/// ### Design Notes
/// - The report is immutable; once constructed, violations cannot be added or removed.
/// - This implementation prioritizes simplicity and predictable behavior for
///   most application-level validation flows.
/// - Frameworks can subclass or replace it with a richer implementation that
///   supports severity levels, localized messages, or grouping by annotation type.
///
/// ### See Also
/// - [ConstraintViolation]
/// - [DetailedConstraintViolation]
/// - [ValidationReport]
/// {@endtemplate}
final class SimpleValidationReport implements ValidationReport {
  /// Internal storage for violations. Immutable after construction.
  final Set<ConstraintViolation> _violations;

  /// Creates a new validation report from the given set of violations.
  ///
  /// The provided set is not defensively copied; callers should ensure
  /// immutability if the source collection is reused elsewhere.
  /// 
  /// {@macro simple_validation_report}
  SimpleValidationReport([this._violations = const {}]);

  @override
  bool isValid() => _violations.isEmpty;

  @override
  Set<ConstraintViolation> getViolations() => _violations;
  
  @override
  Set<ConstraintViolation> getViolationsForProperty(String propertyPath) =>
      _violations.where((v) => v.getPropertyPath() == propertyPath).toSet();

  @override
  String? getFirstViolationMessage() => _violations.isEmpty ? null : _violations.first.getMessage();

  @override
  List<Object?> equalizedProperties() => [_violations];
}

final class SimpleValidationContext implements ValidationContext {
  final Environment _environment;

  SimpleValidationContext(this._environment);

  @override
  Environment getEnvironment() => _environment;
}