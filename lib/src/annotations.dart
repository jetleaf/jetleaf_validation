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
import 'package:meta/meta_meta.dart';

import 'base.dart';
import 'constraint_validators.dart';

/// {@template jetleaf_when_validating}
/// Base class for all **JetLeaf validation annotations** that participate in
/// the declarative validation subsystem.
///
/// Classes extending [WhenValidating] define semantic constraints
/// that can be applied to fields, methods, parameters, or types.  
/// These annotations serve as *metadata carriers* — describing validation
/// rules and the contexts in which they apply — and are coupled with a
/// corresponding [ConstraintValidator] that enforces the rule.
///
/// ### Core Responsibilities
/// - Declares a link between metadata (`@Email`, `@NotEmpty`, etc.)
///   and their runtime validation logic.
/// - Provides optional [payloads] for extended semantics (severity,
///   codes, categories, or contextual metadata).
/// - Supports [groups] to enable selective or staged validation flows.
///
/// ### Constructor Parameters
/// - **[_message]** — Defines the default validation failure message.
///   Can be overridden or localized by validation message resolvers.
/// 
///   ### Example
///   ```dart
///   @Target({TargetKind.fieldType})
///   @Validator(NotEmptyConstraintValidator())
///   final class NotEmpty extends WhenValidating {
///     const NotEmpty({super.message = "Must not be empty"});
///   }
///
///   class UserForm {
///     @NotEmpty(message: "Username cannot be blank")
///     final String username;
///   }
///   ```
/// 
/// - **[payloads]** — A list of [ConstraintPayload] instances that attach
///   auxiliary metadata to the constraint.  
///   Payloads do **not** affect constraint logic directly but may inform:
///   - error reporting systems,
///   - telemetry pipelines,
///   - rule categorization (e.g., “security”, “data-integrity”).
///
///   Example:
///   ```dart
///   @NotEmpty(payloads: [Severity('ERROR')])
///   final String username;
///   ```
///
/// - **[groups]** — A list of [ClassType]s defining validation groups.
///   Groups allow conditional validation: constraints in a given group
///   only run when that group is targeted in the validation request.
///   This is essential for complex object graphs or phased validation flows.
///
///   Example:
///   ```dart
///   final class RegistrationGroup {}
///
///   @Email(groups: [RegistrationGroup])
///   final String email;
///   ```
///
/// ### Example: Custom Constraint Definition
/// ```dart
/// @Target({TargetKind.fieldType})
/// @Validator(NotEmptyConstraintValidator())
/// final class NotEmpty extends WhenValidating {
///   const NotEmpty({super.payloads, super.groups});
/// }
/// ```
///
/// ### Integration Workflow
/// - JetLeaf’s validation engine introspects [WhenValidating] annotations
///   at runtime using reflection.
/// - For each discovered constraint:
///   1. The engine locates the corresponding [ConstraintValidator].
///   2. Calls `isValid()` with the annotated value and annotation metadata.
///   3. Reports any violations, enriched with [payloads] and [groups].
///
/// ### Design Notes
/// - **Extensible**: Serves as the foundation for all JetLeaf constraint annotations.
/// - **Declarative**: Simplifies expressing complex validation logic
///   through annotations rather than procedural code.
/// - **Context-aware**: Integrates seamlessly with environment and pod lifecycle
///   through JetLeaf’s reflection and dependency injection subsystems.
///
/// ### See Also
/// - [ConstraintValidator]
/// - [ConstraintPayload]
/// - [ValidationContext]
/// - [ReflectableAnnotation]
/// - [EqualsAndHashCode]
/// {@endtemplate}
abstract class WhenValidating extends ReflectableAnnotation with EqualsAndHashCode {
  /// The default validation failure message associated with the constraint.
  ///
  /// Used when no custom message is provided by the annotation or when
  /// localization is not applied.
  final String _message;

  /// Optional metadata payloads attached to this constraint.
  ///
  /// Used by reporting systems or custom validators for
  /// severity tagging, categories, or diagnostics.
  final List<ConstraintPayload> payloads;

  /// The validation groups this constraint belongs to.
  ///
  /// Constraints are only validated when their associated
  /// group is included in the active validation context.
  final List<ClassType> groups;

  /// {@macro jetleaf_when_validating}
  const WhenValidating({
    String message = "Validation failed",
    this.payloads = const [],
    this.groups = const [ClassType<DefaultGroup>(PackageNames.VALIDATION)]
  }) : _message = message;

  /// Returns the effective validation failure message for this constraint.
  ///
  /// By default, this returns the static message provided in the constructor
  /// (see [_message]). If a [properties] map is provided, implementations may
  /// use it to interpolate or substitute placeholders within the message,
  /// enabling parameterized or localized error output.
  ///
  /// Example:
  /// ```dart
  /// final message = constraint.getMessage({'min': '3', 'max': '10'});
  /// // "Value must be between 3 and 10"
  /// ```
  ///
  /// Parameters:
  /// - [properties]: An optional map of placeholder names to values used
  ///   for dynamic message substitution.
  ///
  /// Returns:
  /// - A [String] representing the formatted validation error message.
  String getMessage([Map<String, String>? properties]) {
    String message = _message;

    if (properties != null && properties.isNotEmpty) {
      properties.forEach((key, value) {
        // Replace placeholders like {min}, {max}, etc.
        message = message.replaceAll('{$key}', value);
      });
    }

    return message;
  }
}

/// {@template jetleaf_constraint_payload}
/// Marker interface in **JetLeaf Validation** representing *metadata payloads*
/// attached to validation constraints.
///
/// A [ConstraintPayload] allows annotations (such as `@Email`, `@Size`,
/// or `@Pattern`) to carry *auxiliary data* beyond the core validation logic.
/// This metadata is made available to validators, message interpolators,
/// and reporting systems (e.g., diagnostics, structured logs, or telemetry).
///
/// ### Purpose
/// The `ConstraintPayload` abstraction enables advanced validation use cases
/// where additional context or structured metadata is required:
///
/// - Custom **severity levels** (`INFO`, `WARN`, `ERROR`)
/// - **Categories** for grouping or filtering validation messages
/// - **Machine-readable codes** for API responses or error tracking
/// - **Custom actions** or **callbacks** for specific constraint types
///
/// ### Usage
/// To attach a payload to a constraint annotation, declare a `payload` property
/// in the annotation class and assign one or more types implementing this
/// interface.
///
/// ```dart
/// @Target({TargetKind.fieldType})
/// @Validator(NotEmptyConstraintValidator())
/// class NotEmpty extends WhenValidating {
///   final List<Type> payload;
///
///   const NotEmpty({this.payload = const []});
/// }
///
/// // Custom payload
/// final class Severity implements ConstraintPayload {
///   final String level;
///   const Severity(this.level);
/// }
///
/// // Example annotation usage
/// class User {
///   @NotEmpty(payload: [Severity])
///   final String username;
///
///   User(this.username);
/// }
/// ```
///
/// ### Framework Integration
/// - During validation, JetLeaf’s constraint engine can inspect payloads
///   attached to constraint annotations and expose them to:
///   - **Constraint validators**, for dynamic logic decisions.
///   - **Validation reports**, for structured diagnostics.
///   - **Event listeners** or **metrics collectors**, for monitoring.
///
/// ### Example: Severity-based Handling
/// ```dart
/// final severity = annotation.payload
///   .whereType<Severity>()
///   .map((p) => p.level)
///   .firstOrNull ?? 'ERROR';
///
/// if (severity == 'WARN') {
///   // log warning instead of failing
/// }
/// ```
///
/// ### Design Notes
/// - **Pure marker contract** — contains no methods, ensuring lightweight use.
/// - **Extensible** — multiple custom payloads may be defined and combined.
/// - **Declarative** — designed to integrate naturally with Dart metadata.
///
/// ### See Also
/// - [ConstraintValidator]
/// - [WhenValidating]
/// - [Validator]
/// - [ConstraintViolation]
/// - [EmailConstraintValidator]
/// - [EqualsAndHashCode]
/// {@endtemplate}
abstract interface class ConstraintPayload with EqualsAndHashCode {}

/// {@template default_group}
/// Represents the **default validation group** within the JetLeaf validation framework.
///
/// Validation groups in JetLeaf allow you to categorize and selectively execute
/// subsets of constraint checks. This enables complex validation scenarios such as *stepwise* or
/// *contextual validation*.
///
/// The `DefaultGroup` serves as the **baseline group** automatically applied
/// when no explicit group is specified in validation calls. In most use cases,
/// developers do not need to reference it directly; the framework assumes
/// membership in this group for all constraints unless configured otherwise.
///
/// ### Overview
/// - **Type:** Abstract interface (non-instantiable)
/// - **Implements:** [EqualsAndHashCode] — provides consistent identity semantics
/// - **Usage scope:** Acts as a symbolic marker rather than a data container
///
/// ### Semantics
/// When a validator (e.g., `Validator.validate()`) is invoked without specifying
/// groups:
///
/// ```dart
/// validator.validate(user);
/// ```
///
/// JetLeaf implicitly applies `DefaultGroup`, ensuring all constraints that
/// belong to this group (the default for all annotations) are evaluated.
///
/// To target multiple groups, include this one explicitly:
///
/// ```dart
/// validator.validate(user, groups: {DefaultGroup, AdminGroup});
/// ```
///
/// ### Implementation Notes
/// - This interface contains **no members** beyond those inherited from
///   [EqualsAndHashCode].  
/// - Its sole purpose is to provide a canonical, reflective type reference
///   recognized by JetLeaf’s group resolution engine.
/// - Because it is an interface with a `const` constructor, it can be used
///   directly in compile-time group sets:
///
/// ```dart
/// const defaultGroup = DefaultGroup();
/// ```
///
/// ### See Also
/// - [ValidationReport] — reports violations across groups.
/// - [ConstraintViolation.groups] — exposes the group set for each violation.
/// - [ConstraintValidator] — executes validations by group.
///
/// ### Example
/// ```dart
/// @NotNull(groups: {DefaultGroup})
/// final String? email;
///
/// final report = validator.validate(this, groups: {DefaultGroup});
/// if (!report.isValid()) {
///   print(report.getFirstViolationMessage());
/// }
/// ```
///
/// {@endtemplate}
abstract interface class DefaultGroup with EqualsAndHashCode {
  /// Creates a constant marker instance of the default validation group.
  ///
  /// Typically not instantiated directly — used primarily for type reference
  /// during validation group resolution.
  const DefaultGroup();

  /// Returns the reflective [Class] instance representing the
  /// [DefaultGroup] type within the validation package.
  ///
  /// This method is primarily used by the JetLeaf reflection and
  /// validation subsystems to dynamically resolve metadata, annotations,
  /// and constraint group associations at runtime.
  ///
  /// Example:
  /// ```dart
  /// final clazz = DefaultGroup.getClass();
  /// print(clazz.getPackage()?.getName()); // "validation"
  /// ```
  ///
  /// See also:
  /// - [PackageNames.VALIDATION] — the canonical package name used for
  ///   validation-related types.
  static Class getClass() => Class<DefaultGroup>(null, PackageNames.VALIDATION);
}

// ------------------------------------------------------------------------------------------------------------------
// ANNOTATIONS
// ------------------------------------------------------------------------------------------------------------------

/// {@template jetleaf_validator_annotation}
/// A meta-annotation in **JetLeaf Validation** used to associate a
/// specific [ConstraintValidator] implementation with a custom constraint
/// annotation.
///
/// The `@Constraint` annotation acts as the **binding mechanism**
/// between declarative constraint annotations (like `@NotEmpty`, `@Size`,
/// or `@Pattern`) and their corresponding validator logic classes that
/// enforce those constraints at runtime.
///
/// ### Purpose
/// In JetLeaf’s validation model, custom annotations describe validation
/// semantics, while `ConstraintValidator` instances provide the execution
/// logic. The `@Constraint` annotation formally connects these two parts.
///
/// By applying `@Constraint` to a constraint annotation definition,
/// JetLeaf automatically discovers and invokes the associated
/// validator during validation operations.
///
/// ### Example
/// ```dart
/// @Target({TargetKind.fieldType})
/// @Constraint([NotEmptyConstraintValidator())
/// class NotEmpty extends ReflectableAnnotation {
///   const NotEmpty();
/// }
///
/// class NotEmptyConstraintValidator
///     implements ConstraintValidator<NotEmpty, String> {
///   @override
///   bool isValid(String value, NotEmpty annotation) {
///     return value.trim().isNotEmpty;
///   }
/// }
/// ```
///
/// ### How It Works
/// - The `@Constraint` annotation is attached **to the constraint annotation**
///   (not directly to a field or class).
/// - During the JetLeaf validation bootstrap process, all annotations marked
///   with `@Constraint` are registered with their corresponding
///   [ConstraintValidator] implementations.
/// - When a field or parameter annotated with such a constraint is validated,
///   the JetLeaf runtime looks up and executes the associated validator.
///
/// ### Use Cases
/// - **Simple field validation:**  
///   ```dart
///   @NotEmpty()
///   final String username;
///   ```
/// - **Parameterized annotations:**  
///   ```dart
///   @Target({TargetKind.fieldType})
///   @Constraint([SizeValidator())
///   class Size extends ReflectableAnnotation {
///     final int min;
///     final int max;
///     const Size({this.min = 0, this.max = 2147483647});
///   }
///   ```
///
/// ### Notes
/// - Each constraint annotation must have exactly **one** corresponding
///   [Constraint] annotation.  
/// - The [ConstraintValidator] instance should be stateless and reusable.  
/// - Validators may be automatically instantiated and cached by the JetLeaf
///   validation subsystem.  
/// - The JetLeaf runtime ensures that each validator’s generic types
///   (annotation and value) align with the annotated element being validated.
///
/// ### Reflection Integration
/// Since `Constraint` extends [ReflectableAnnotation], it participates fully
/// in JetLeaf’s reflection-based metadata model, allowing automatic discovery
/// without manual registration or hard-coded lookup.
///
/// ### See Also
/// - [ConstraintValidator]
/// - [ReflectableAnnotation]
/// - [ConstraintViolation]
/// - [ValidationContext]
///
/// {@endtemplate}
final class Constraint extends ReflectableAnnotation {
  /// The key used to store or retrieve validator annotations in metadata.
  ///
  /// This constant typically serves as the field name for reflection-based
  /// lookups where `Constraint` validators are registered.
  ///
  /// Example usage:
  /// ```dart
  /// final validators = Class<Annotation>().getField(Constraint.FIELD_KEY);
  /// ```
  static const String FIELD_KEY = "validators";

  /// The [ConstraintValidator] responsible for enforcing the constraint
  /// logic associated with the annotated constraint annotation.
  ///
  /// JetLeaf uses this instance to evaluate the validity of annotated
  /// elements during runtime validation.
  final List<ConstraintValidator> validators;

  /// Creates a new [Constraint] annotation that binds a specific
  /// [ConstraintValidator] implementation to a constraint annotation.
  ///
  /// The [validators] provided here defines how the annotated
  /// constraint is enforced.
  ///
  /// **Example:**
  /// ```dart
  /// const Constraint(NotEmptyConstraintValidator());
  /// ```
  const Constraint(this.validators);

  /// Returns the runtime type of this annotation for reflection-based
  /// discovery within the JetLeaf validation subsystem.
  @override
  Type get annotationType => Constraint;
}

/// {@template jetleaf_email}
/// A **constraint annotation** that validates that the annotated element
/// is a syntactically valid **email address** according to the RFC 5322 standard,
/// or a custom regular expression if provided.
///
/// This annotation is part of JetLeaf’s validation framework and works
/// in conjunction with [EmailConstraintValidator] to enforce correct email
/// formatting across string properties, parameters, and return values.
///
/// ### Validation Rules
/// - Validation **passes** if the value is `null`.  
///   (Use [`@NotNull`] or [`@NotBlank`] alongside to enforce non-null inputs.)
/// - Validation **passes** if:
///   - The value matches the built-in RFC 5322-compliant pattern, or
///   - A custom [pattern] is supplied and the value matches it.
/// - Validation **fails** otherwise.
///
/// ### Example
/// ```dart
/// class User {
///   @Email(message: "Invalid email format")
///   final String email;
///
///   const User(this.email);
/// }
///
/// final user = User("john.doe@example.com");
/// ```
///
/// ### Custom Pattern
/// You can override the default email syntax by supplying your own [pattern]:
///
/// ```dart
/// class InternalUser {
///   @Email(
///     pattern: r'^[a-z]+@[a-z]+\.internal$',
///     message: "Must be an internal email address"
///   )
///   final String email;
///
///   const InternalUser(this.email);
/// }
/// ```
///
/// ### Example Validation Results
/// | Input Value | Pattern | Result |
/// |--------------|----------|---------|
/// | `"john.doe@example.com"` | RFC 5322 | ✅ Pass |
/// | `"user@internal"` | RFC 5322 | ❌ Fail |
/// | `"dev@corp.internal"` | `^[a-z]+@[a-z]+\.internal$` | ✅ Pass |
///
/// ### Design Notes
/// - Defaults to a robust RFC 5322-compliant regex, suitable for general use.
/// - Allows overriding with simpler domain-specific or stricter patterns.
/// - Does **not** perform MX-record or network validation — purely syntactic.
/// - Safe to use on fields, parameters, or methods.
///
/// ### See Also
/// - [EmailConstraintValidator]
/// - [NotBlank]
/// - [NotNull]
/// - [Pattern]
/// - [WhenValidating]
/// {@endtemplate}
@Constraint([EmailConstraintValidator()])
@Target({TargetKind.field, TargetKind.parameter, TargetKind.method})
final class Email extends WhenValidating {
  /// Email validation pattern (RFC 5322 compliant by default)
  final String? pattern;

  /// {@macro jetleaf_email}
  const Email({super.message = "must be a valid email address", this.pattern, super.groups, super.payloads});
  
  @override
  String toString() => 'Email(message: $_message, pattern: $pattern, groups: $groups, payloads: $payloads)';

  @override
  List<Object?> equalizedProperties() => [_message, pattern, groups, payloads];
  
  @override
  Type get annotationType => Email;
}

/// {@template jetleaf_in_future}
/// A **constraint annotation** that validates that the annotated
/// [DateTime] element represents a point **in the future** relative
/// to the current system or application timezone.
///
/// This annotation is part of the JetLeaf validation framework and
/// works in conjunction with [InFutureConstraintValidator] to ensure
/// temporal correctness for fields, method parameters, or return values.
///
/// ### Validation Rules
/// - Validation **passes** if the value is `null`.  
///   (Use [NotNull] alongside this annotation to enforce non-null inputs.)
/// - Validation **passes** if the value represents a future date/time
///   relative to the current time in the configured application timezone.
/// - Validation **fails** if the date/time is in the past or exactly now.
///
/// ### Timezone Awareness
/// - If an application timezone is configured in the environment (via
///   `application.timezone`), the validation will be evaluated using that zone.
/// - Otherwise, the system default timezone is used.
///
/// ### Example
/// ```dart
/// class Event {
///   @InFuture(message: "Start date must be in the future")
///   final DateTime startDate;
///
///   const Event(this.startDate);
/// }
///
/// final event = Event(DateTime.now().add(Duration(days: 1))); // ✅ Valid
/// final invalidEvent = Event(DateTime.now().subtract(Duration(days: 1))); // ❌ Invalid
/// ```
///
/// ### Usage Notes
/// - Can be applied to **fields**, **parameters**, and **methods**.
/// - Useful for scheduling, deadline, or expiration validation.
/// - Works best in combination with [NotNull] to ensure a date is always present.
///
/// ### See Also
/// - [InFutureConstraintValidator]
/// - [InPast]
/// - [NotNull]
/// - [WhenValidating]
/// {@endtemplate}
@Constraint([InFutureConstraintValidator()])
@Target({TargetKind.field, TargetKind.parameter, TargetKind.method})
final class InFuture extends WhenValidating {
  /// {@macro jetleaf_in_future}
  const InFuture({super.message = "must be a future date", super.groups, super.payloads});

  @override
  Type get annotationType => InFuture;

  @override
  List<Object?> equalizedProperties() => [_message, groups, payloads];

  @override
  String toString() => 'InFuture(message: $_message, groups: $groups, payloads: $payloads)';
}

/// {@template jetleaf_size}
/// A **constraint annotation** that validates that the annotated
/// element’s size or length falls within a specified range `[min, max]`.
///
/// This annotation works with [SizeConstraintValidator] to enforce
/// constraints on:
/// - [String] values (length)
/// - [Iterable] and [List] values (number of elements)
/// - [Map] values (number of entries)
/// - Numeric types ([num]) (value itself treated as "size")
///
/// ### Validation Rules
/// - Validation **passes** if the value is `null`.  
///   (Use [NotNull] alongside this annotation to enforce non-null values.)
/// - Validation **passes** if `min <= size <= max`.
/// - Validation **fails** if the value’s size is outside the defined range.
///
/// ### Parameters
/// - [min]: the minimum inclusive bound (defaults to `Integer.MIN_VALUE`)
/// - [max]: the maximum inclusive bound (defaults to `Integer.MAX_VALUE`)
/// - [_message]: error message template (supports `{min}` and `{max}` placeholders)
///
/// ### Example
/// ```dart
/// class User {
///   @Size(min: 3, max: 20, message: "Username must be between 3 and 20 characters")
///   final String username;
///
///   @Size(min: 1, max: 10)
///   final List<String> roles;
///
///   const User(this.username, this.roles);
/// }
///
/// final validUser = User("jetleaf", ["admin"]); // ✅ Valid
/// final invalidUser = User("ab", []); // ❌ Invalid
/// ```
///
/// ### Usage Notes
/// - Can be applied to **fields**, **parameters**, and **methods**.
/// - Supports complex collections or nested structures when combined with custom validators.
/// - Works best in combination with [NotNull] to ensure a value is always present.
///
/// ### See Also
/// - [SizeConstraintValidator]
/// - [Min]
/// - [Max]
/// - [WhenValidating]
/// {@endtemplate}
@Constraint([SizeConstraintValidator()])
@Target({TargetKind.field, TargetKind.parameter, TargetKind.method})
final class Size extends WhenValidating {
  /// Minimum allowed size (inclusive).
  final int min;

  /// Maximum allowed size (inclusive).
  final int max;

  /// {@macro jetleaf_size}
  const Size({
    this.min = Integer.MIN_VALUE,
    this.max = Integer.MAX_VALUE,
    super.message = "length must be between {min} and {max}",
    super.groups,
    super.payloads
  });

  @override
  Type get annotationType => Size;

  @override
  List<Object?> equalizedProperties() => [_message, groups, payloads];

  @override
  String toString() => 'InLength(message: $_message, groups: $groups, payloads: $payloads, min: $min, max: $max)';
}

/// {@template jetleaf_max}
/// A **constraint annotation** that validates that the annotated
/// numeric element does **not exceed** a specified maximum value.
///
/// This annotation works with [MaxConstraintValidator] to enforce
/// constraints on numeric types (`int`, `double`, `num`).
///
/// ### Validation Rules
/// - Validation **passes** if the value is `null`.  
///   (Use [NotNull] alongside this annotation to enforce non-null values.)
/// - Validation **passes** if `value <= annotation.value`.
/// - Validation **fails** if the value is greater than the defined maximum.
///
/// ### Parameters
/// - [value]: the maximum allowed value (inclusive)
/// - [_message]: error message template (supports `{value}` placeholder)
///
/// ### Example
/// ```dart
/// class Product {
///   @Max(100, message: "Price must not exceed 100")
///   final int price;
///
///   const Product(this.price);
/// }
///
/// final validProduct = Product(50); // ✅ Valid
/// final invalidProduct = Product(150); // ❌ Invalid
/// ```
///
/// ### Usage Notes
/// - Can be applied to **fields**, **parameters**, and **methods**.
/// - Works best with other numeric constraints such as [Min] or [Positive].
///
/// ### See Also
/// - [MaxConstraintValidator]
/// - [Min]
/// - [Positive]
/// - [WhenValidating]
/// {@endtemplate}
@Constraint([MaxConstraintValidator()])
@Target({TargetKind.field, TargetKind.parameter, TargetKind.method})
class Max extends WhenValidating {
  /// The maximum allowed value (inclusive).
  final num value;
  
  /// {@macro jetleaf_max}
  const Max(this.value, {super.message = "must be less than or equal to {value}", super.groups, super.payloads});
  
  @override
  String toString() => 'Max(value: $value, message: $_message, groups: $groups, payloads: $payloads)';
  
  @override
  Type get annotationType => Max;

  @override
  List<Object?> equalizedProperties() => [value, _message, groups, payloads];
}

/// {@template jetleaf_min}
/// A **constraint annotation** that validates that the annotated
/// numeric element does **not fall below** a specified minimum value.
///
/// This annotation works with [MinConstraintValidator] to enforce
/// constraints on numeric types (`int`, `double`, `num`).
///
/// ### Validation Rules
/// - Validation **passes** if the value is `null`.  
///   (Use [NotNull] alongside this annotation to enforce non-null values.)
/// - Validation **passes** if `value >= annotation.value`.
/// - Validation **fails** if the value is less than the defined minimum.
///
/// ### Parameters
/// - [value]: the minimum allowed value (inclusive)
/// - [_message]: error message template (supports `{value}` placeholder)
///
/// ### Example
/// ```dart
/// class Product {
///   @Min(1, message: "Quantity must be at least 1")
///   final int quantity;
///
///   const Product(this.quantity);
/// }
///
/// final validProduct = Product(5); // ✅ Valid
/// final invalidProduct = Product(0); // ❌ Invalid
/// ```
///
/// ### Usage Notes
/// - Can be applied to **fields**, **parameters**, and **methods**.
/// - Works best with other numeric constraints such as [Max] or [Positive].
///
/// ### See Also
/// - [MinConstraintValidator]
/// - [Max]
/// - [Positive]
/// - [WhenValidating]
/// {@endtemplate}
@Constraint([MinConstraintValidator()])
@Target({TargetKind.field, TargetKind.parameter, TargetKind.method})
class Min extends WhenValidating {
  /// The minimum allowed value (inclusive).
  final num value;
  
  /// {@macro jetleaf_min}
  const Min(this.value, {super.message = "must be greater than or equal to {value}", super.groups, super.payloads});
  
  @override
  String toString() => 'Min(value: $value, message: $_message, groups: $groups, payloads: $payloads)';
  
  @override
  Type get annotationType => Min;

  @override
  List<Object?> equalizedProperties() => [value, _message, groups, payloads];
}

/// {@template jetleaf_negative}
/// A **constraint annotation** that validates that the annotated numeric
/// element is **strictly negative** (less than 0).
///
/// This annotation works with [NegativeConstraintValidator] to enforce
/// constraints on numeric types (`int`, `double`, `num`).
///
/// ### Validation Rules
/// - Validation **passes** if the value is `null`.  
///   (Use [NotNull] alongside this annotation to enforce non-null values.)
/// - Validation **passes** if `value < 0`.
/// - Validation **fails** if the value is zero or positive.
///
/// ### Parameters
/// - [_message]: error message template displayed when validation fails
///
/// ### Example
/// ```dart
/// class Account {
///   @Negative(message: "Balance must be negative")
///   final double balance;
///
///   const Account(this.balance);
/// }
///
/// final validAccount = Account(-50.0); // ✅ Valid
/// final invalidAccount = Account(10.0); // ❌ Invalid
/// ```
///
/// ### Usage Notes
/// - Can be applied to **fields**, **parameters**, and **methods**.
/// - Works best with other numeric constraints like [Min], [Max], or [Positive].
///
/// ### See Also
/// - [NegativeConstraintValidator]
/// - [Min]
/// - [Max]
/// - [Positive]
/// - [WhenValidating]
/// {@endtemplate}
@Constraint([NegativeConstraintValidator()])
@Target({TargetKind.field, TargetKind.parameter, TargetKind.method})
final class Negative extends WhenValidating {
  /// {@macro jetleaf_negative}
  const Negative({super.message = "must be less than 0", super.groups, super.payloads});

  @override
  Type get annotationType => Negative;

  @override
  List<Object?> equalizedProperties() => [_message, groups, payloads];

  @override
  String toString() => 'Negative(message: $_message, groups: $groups, payloads: $payloads)';
}

/// {@template jetleaf_positive}
/// A **constraint annotation** that validates that the annotated numeric
/// element is **strictly positive** (greater than 0).
///
/// This annotation works with [PositiveConstraintValidator] to enforce
/// constraints on numeric types (`int`, `double`, `num`).
///
/// ### Validation Rules
/// - Validation **passes** if the value is `null`.  
///   (Use [NotNull] alongside this annotation to enforce non-null values.)
/// - Validation **passes** if `value > 0`.
/// - Validation **fails** if the value is zero or negative.
///
/// ### Parameters
/// - [_message]: error message template displayed when validation fails
///
/// ### Example
/// ```dart
/// class Account {
///   @Positive(message: "Deposit must be positive")
///   final double deposit;
///
///   const Account(this.deposit);
/// }
///
/// final validAccount = Account(50.0); // ✅ Valid
/// final invalidAccount = Account(-10.0); // ❌ Invalid
/// ```
///
/// ### Usage Notes
/// - Can be applied to **fields**, **parameters**, and **methods**.
/// - Works best with other numeric constraints like [Min], [Max], or [Negative].
///
/// ### See Also
/// - [PositiveConstraintValidator]
/// - [Min]
/// - [Max]
/// - [Negative]
/// - [WhenValidating]
/// {@endtemplate}
@Constraint([PositiveConstraintValidator()])
@Target({TargetKind.field, TargetKind.parameter, TargetKind.method})
final class Positive extends WhenValidating {
  /// {@macro jetleaf_positive}
  const Positive({super.message = "must be greater than 0", super.groups, super.payloads});

  @override
  Type get annotationType => Positive;

  @override
  List<Object?> equalizedProperties() => [_message, groups, payloads];

  @override
  String toString() => 'Positive(message: $_message, groups: $groups, payloads: $payloads)';
}

/// {@template jetleaf_not_blank}
/// A **constraint annotation** that validates that the annotated `String`
/// is **not null, empty, or composed solely of whitespace characters**.
///
/// This annotation works with [NotBlankConstraintValidator] to enforce
/// constraints on `String` fields, method parameters, or return values.
///
/// ### Validation Rules
/// - Validation **fails** if the value is `null`.
/// - Validation **fails** if the string is empty (`""`).
/// - Validation **fails** if the string contains only whitespace characters.
/// - Validation **passes** if the string contains at least one non-whitespace character.
///
/// ### Parameters
/// - [_message]: error message template displayed when validation fails.
///
/// ### Example
/// ```dart
/// class User {
///   @NotBlank(message: "Username cannot be blank")
///   final String username;
///
///   const User(this.username);
/// }
///
/// final validUser = User("alice");  // ✅ Valid
/// final invalidUser1 = User("");    // ❌ Invalid
/// final invalidUser2 = User("   "); // ❌ Invalid
/// ```
///
/// ### Usage Notes
/// - Can be applied to **fields**, **parameters**, and **methods**.
/// - Use alongside other constraints like [NotNull] to enforce stricter validation.
///
/// ### See Also
/// - [NotBlankConstraintValidator]
/// - [NotNull]
/// - [NotEmpty]
/// - [WhenValidating]
/// {@endtemplate}
@Constraint([NotBlankConstraintValidator()])
@Target({TargetKind.field, TargetKind.parameter, TargetKind.method})
final class NotBlank extends WhenValidating {
  /// {@macro jetleaf_not_blank}
  const NotBlank({super.message = "must not be blank", super.groups, super.payloads});

  @override
  Type get annotationType => NotBlank;

  @override
  List<Object?> equalizedProperties() => [_message, groups, payloads];

  @override
  String toString() => 'NotBlank(message: $_message, groups: $groups, payloads: $payloads)';
}

/// {@template jetleaf_not_empty}
/// A **constraint annotation** that validates that the annotated value is **not null or empty**.
///
/// This annotation works with [NotEmptyConstraintValidator] to enforce constraints on:
/// - `String` values (must have length > 0),
/// - `Iterable` values (must contain at least one element),
/// - `Map` values (must contain at least one entry),
/// - Any other object type (always considered valid unless `null`).
///
/// ### Validation Rules
/// - Validation **fails** if the value is `null`.
/// - Validation **fails** if the value is an empty `String`, `Iterable`, or `Map`.
/// - Validation **passes** for non-empty values of the supported types.
/// - Validation **always passes** for unsupported object types, unless `null`.
///
/// ### Parameters
/// - [_message]: error message template displayed when validation fails.
///
/// ### Example
/// ```dart
/// class User {
///   @NotEmpty(message: "Username cannot be empty")
///   final String username;
///
///   @NotEmpty
///   final List<String> roles;
///
///   const User(this.username, this.roles);
/// }
///
/// final validUser = User("alice", ["admin"]);  // ✅ Valid
/// final invalidUser1 = User("", ["admin"]);    // ❌ Invalid (empty string)
/// final invalidUser2 = User("bob", []);        // ❌ Invalid (empty list)
/// ```
///
/// ### Usage Notes
/// - Can be applied to **fields**, **parameters**, and **methods**.
/// - Use alongside other constraints like [NotNull] or [NotBlank] to enforce stricter validation.
///
/// ### See Also
/// - [NotEmptyConstraintValidator]
/// - [NotNull]
/// - [NotBlank]
/// - [WhenValidating]
/// {@endtemplate}
@Constraint([NotEmptyConstraintValidator()])
@Target({TargetKind.field, TargetKind.parameter, TargetKind.method})
final class NotEmpty extends WhenValidating {
  /// {@macro jetleaf_not_empty}
  const NotEmpty({super.message = "must not be empty", super.groups, super.payloads});

  @override
  Type get annotationType => NotEmpty;

  @override
  List<Object?> equalizedProperties() => [_message, groups, payloads];

  @override
  String toString() => 'NotEmpty(message: $_message, groups: $groups, payloads: $payloads)';
}

/// {@template jetleaf_not_null}
/// A **constraint annotation** that validates that the annotated value is **not null**.
///
/// This annotation works with [NotNullConstraintValidator] to enforce constraints on:
/// - Any object type, ensuring it is not `null`.
///
/// ### Validation Rules
/// - Validation **fails** if the value is `null`.
/// - Validation **passes** for all non-null values.
///
/// ### Parameters
/// - [_message]: error message template displayed when validation fails.
///
/// ### Example
/// ```dart
/// class User {
///   @NotNull(message: "Username cannot be null")
///   final String username;
///
///   const User(this.username);
/// }
///
/// final validUser = User("alice"); // ✅ Valid
/// final invalidUser = User(null);  // ❌ Invalid
/// ```
///
/// ### Usage Notes
/// - Can be applied to **fields**, **parameters**, and **methods**.
/// - Use alongside other constraints like [NotEmpty] or [NotBlank] to enforce stricter validation.
///
/// ### See Also
/// - [NotNullConstraintValidator]
/// - [NotEmpty]
/// - [NotBlank]
/// - [WhenValidating]
/// {@endtemplate}
@Constraint([NotNullConstraintValidator()])
@Target({TargetKind.field, TargetKind.parameter, TargetKind.method})
final class NotNull extends WhenValidating {
  /// {@macro jetleaf_not_null}
  const NotNull({super.message = "must not be null", super.groups, super.payloads});

  @override
  Type get annotationType => NotNull;

  @override
  List<Object?> equalizedProperties() => [_message, groups, payloads];

  @override
  String toString() => 'NotNull(message: $_message, groups: $groups, payloads: $payloads)';
}

/// {@template jetleaf_in_past}
/// A **constraint annotation** that validates that the annotated `DateTime` value
/// is in the **past** relative to the current time.
///
/// This annotation works with [InPastConstraintValidator] to enforce constraints on:
/// - `DateTime` fields
/// - Method parameters
/// - Method return values
///
/// ### Validation Rules
/// - Validation **passes** if the value is `null` (nulls are considered valid by default).
/// - Validation **fails** if the value is a `DateTime` in the future relative to the current time.
/// - Supports timezone-aware comparison if the application environment specifies a timezone.
///
/// ### Example
/// ```dart
/// class Event {
///   @InPast(message: "Event date must be in the past")
///   final DateTime date;
///
///   const Event(this.date);
/// }
///
/// final pastEvent = Event(DateTime(2000, 1, 1)); // ✅ Valid
/// final futureEvent = Event(DateTime(3000, 1, 1)); // ❌ Invalid
/// ```
///
/// ### Usage Notes
/// - Can be applied to **fields**, **parameters**, and **methods**.
/// - Integrates with [ValidationContext] to respect environment timezone settings.
///
/// ### See Also
/// - [InPastConstraintValidator]
/// - [InFuture]
/// - [WhenValidating]
/// {@endtemplate}
@Constraint([InPastConstraintValidator()])
@Target({TargetKind.field, TargetKind.parameter, TargetKind.method})
final class InPast extends WhenValidating {
  /// {@macro jetleaf_in_past}
  const InPast({super.message = "must be a past date", super.groups, super.payloads});

  @override
  Type get annotationType => InPast;

  @override
  List<Object?> equalizedProperties() => [_message, groups, payloads];

  @override
  String toString() => 'InPast(message: $_message, groups: $groups, payloads: $payloads)';
}

/// {@template jetleaf_pattern}
/// A **constraint annotation** that validates that the annotated `String`
/// value matches a specific regular expression pattern.
///
/// This annotation works with [PatternConstraintValidator] to enforce constraints on:
/// - `String` fields
/// - Method parameters
/// - Method return values
///
/// ### Validation Rules
/// - Validation **passes** if the value is `null` (nulls are considered valid by default).
/// - Validation **fails** if the value does not match the provided regular expression.
///
/// ### Example
/// ```dart
/// class User {
///   @Pattern(r'^[a-zA-Z0-9]+$', message: "Username must be alphanumeric")
///   final String username;
///
///   const User(this.username);
/// }
///
/// final validUser = User("john123");   // ✅ Valid
/// final invalidUser = User("john@123"); // ❌ Invalid
/// ```
///
/// ### Usage Notes
/// - Can be applied to **fields**, **parameters**, and **methods**.
/// - The `pattern` property is **mandatory** and should contain a valid regular expression.
///
/// ### See Also
/// - [PatternConstraintValidator]
/// - [WhenValidating]
/// {@endtemplate}
@Constraint([PatternConstraintValidator()])
@Target({TargetKind.field, TargetKind.parameter, TargetKind.method})
final class Pattern extends WhenValidating {
  /// The regular expression pattern that the value must match.
  final String regexp;

  /// {@macro jetleaf_pattern}
  const Pattern(this.regexp, {super.message = "must match pattern {regexp}", super.groups, super.payloads});
  
  @override
  String toString() => 'Pattern(message: $_message, pattern: $regexp, groups: $groups, payloads: $payloads)';

  @override
  List<Object?> equalizedProperties() => [_message, regexp, groups, payloads];
  
  @override
  Type get annotationType => Pattern;
}

/// {@template jetleaf_valid}
/// Marks a **field** for recursive validation.
///
/// When a field is annotated with `@Valid`, the JetLeaf validation subsystem
/// will recursively validate the object assigned to that field, applying
/// all constraints present on the target object's class.
///
/// ### Features
/// - Can be applied only to **fields** (`TargetKind.field`).
/// - Supports **validation groups** to selectively trigger validation on
///   specific constraint groups.
/// - Enables **nested validation**, useful for DTOs, entities, or complex types.
///
/// ### Example
/// ```dart
/// class Address {
///   @NotBlank()
///   final String street;
///
///   @NotBlank()
///   final String city;
///
///   const Address(this.street, this.city);
/// }
///
/// class User {
///   @NotBlank()
///   final String name;
///
///   @Valid()
///   final Address address;
///
///   const User(this.name, this.address);
/// }
///
/// // When validating a User instance, the Address fields are validated automatically.
/// ```
///
/// ### Groups
/// You can restrict validation to specific groups by passing a list of classes:
/// ```dart
/// @Valid([ClassType<AdminGroup>(), ClassType<AuditGroup>()])
/// final Address address;
/// ```
///
/// This ensures that only constraints belonging to these groups are validated.
/// {@endtemplate}
@Target({TargetKind.field})
class Valid extends ReflectableAnnotation {
  /// Optional list of validation groups to apply to the target field.
  final List<ClassType> groups;

  /// {@macro jetleaf_valid}
  const Valid([this.groups = const []]);

  @override
  Type get annotationType => Valid;

  @override
  String toString() => 'Valid($groups)';
}

/// {@template jetleaf_validated}
/// Marks a method or a method parameter for validation according to
/// associated **constraint annotations** (e.g., `@NotNull`, `@Email`, `@Size`).
///
/// When applied:
/// - **On a parameter:** the validation subsystem ensures that the parameter value
///   satisfies all relevant constraints before method execution.
/// - **On a method:** all parameters annotated with `@Validated` or constraints
///   are validated according to the declared groups.
///
/// ### Features
/// - Can be applied to **method parameters** and **methods**.
/// - Supports **validation groups** for selective constraint evaluation.
/// - Integrates automatically with JetLeaf’s validation infrastructure.
///
/// ### Example
/// ```dart
/// class UserService {
///   void createUser(@Validated() @NotNull() String username,
///                   @Validated() @Email() String email) {
///     // Parameters are validated automatically
///   }
///
///   @Validated()
///   void updateUser(@NotNull() String userId, @Email() String newEmail) {
///     // Method-level validation validates all parameters according to their constraints
///   }
/// }
/// ```
///
/// ### Groups
/// Validation can be scoped to a specific **group** using the optional `group` parameter:
/// ```dart
/// void updateUser(@Validated(ClassType<AdminGroup>()) @NotNull() String userId) { ... }
/// ```
///
/// ### Notes
/// - If no group is provided, the **default validation group** is used.
/// - Works in combination with annotations extending [WhenValidating].
/// {@endtemplate}
@Target({TargetKind.parameter, TargetKind.method, TargetKind.classType})
final class Validated extends ReflectableAnnotation {
  /// The optional validation group to which this parameter or method belongs.
  final List<ClassType> group;

  /// {@macro jetleaf_validated}
  const Validated([this.group = const []]);

  @override
  Type get annotationType => Validated;

  @override
  String toString() => 'Validated($group)';
}