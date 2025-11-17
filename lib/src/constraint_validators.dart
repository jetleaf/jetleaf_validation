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
import 'package:jetleaf_core/context.dart';
import 'package:jetleaf_env/env.dart';

import 'annotations.dart';
import 'base.dart';

/// {@template jetleaf_email_constraint_validator}
/// A concrete [ConstraintValidator] implementation in **JetLeaf Validation**
/// responsible for enforcing the `@Email` constraint on `String`-typed fields.
///
/// The [EmailConstraintValidator] ensures that a given string value represents
/// a syntactically valid email address. It supports both:
///
/// - **Custom patterns** defined in the annotation, and  
/// - **Default JetLeaf validation logic**, which uses a built-in
///   email pattern matcher through [StringExtensions.isEmail].
///
/// ### Validation Rules
/// 1. **Null Values**
///    - If the validated value is `null`, the validator **returns `true`**
///      (i.e., passes validation).  
///      This design allows for composability with the `@NotNull` constraint:
///      `@Email` only checks syntax, while `@NotNull` enforces presence.
///
/// 2. **Custom Regular Expression**
///    - If the [Email.pattern] property is set, validation is performed
///      using that custom regular expression:
///      ```dart
///      @Email(pattern: r'^[a-z0-9._%+-]+@example\.com$')
///      ```
///      This allows domain-specific or stricter email rules.
///
/// 3. **Default Validation**
///    - If no pattern is provided, JetLeaf falls back to the built-in
///      `isEmail` extension, which follows RFC 5322-compatible
///      semantics for email syntax checking.
///
/// ### Example
/// ```dart
/// @Target({TargetKind.fieldType})
/// @Constraint(EmailConstraintValidator())
/// class Email extends WhenValidating {
///   final String? pattern;
///   const Email({this.pattern});
/// }
///
/// class User {
///   @Email()
///   final String email;
///
///   User(this.email);
/// }
/// ```
///
/// ### Behavior
/// | Input Value                | Custom Pattern | Valid? | Explanation                        |
/// |-----------------------------|----------------|--------|------------------------------------|
/// | `"user@example.com"`        | ❌             | ✅     | Matches default pattern            |
/// | `"invalid_email"`           | ❌             | ❌     | Missing `@` symbol                 |
/// | `"foo@bar.com"`             | `@example.com` | ❌     | Does not match custom pattern      |
/// | `null`                      | any            | ✅     | Nulls are ignored (use `@NotNull`) |
///
/// ### Design Notes
/// - **Null-safe:** Uses `String?` generics to support nullable fields.
/// - **Composable:** Pairs naturally with constraints like `@NotEmpty` or
///   `@NotNull` to enforce both presence and syntactic correctness.
/// - **Extensible:** Can be subclassed or replaced to integrate alternative
///   regex libraries or stricter validation rules.
///
/// ### See Also
/// - [ConstraintValidator]
/// - [Email]
/// - [WhenValidating]
/// - [Constrained]
/// - [StringExtensions.isEmail]
/// {@endtemplate}
final class EmailConstraintValidator implements ConstraintValidator<Email, String> {
  /// {@macro jetleaf_email_constraint_validator}
  const EmailConstraintValidator();

  @override
  bool isValid(String? value, Email annotation, ValidationContext context) {
    if (value == null) {
      return true;
    }

    if (annotation.pattern != null) {
      return RegExp(annotation.pattern!).hasMatch(value);
    }

    return value.isEmail;
  }
}

/// {@template jetleaf_in_future_constraint_validator}
/// A [ConstraintValidator] implementation that validates whether a given
/// [DateTime] value represents a **future point in time** relative to the
/// current moment.
///
/// This validator supports timezone-aware comparisons through the
/// JetLeaf [Environment] and the [AbstractApplicationContext.APPLICATION_TIMEZONE] property,
/// ensuring consistent validation behavior across distributed nodes
/// and environments.
///
/// ### Validation Logic
/// The constraint passes if:
/// - The value is `null` (null values are considered valid unless
///   otherwise constrained by additional annotations such as `@NotNull`).
/// - The provided [DateTime] occurs **after** the current time, either in
///   the system’s local timezone or a configured application timezone.
///
/// ### Timezone Behavior
/// If the environment defines:
/// ```text
/// application.timezone = "UTC"
/// ```
/// the validator converts both the provided value and the current time
/// to the specified [ZoneId] before performing comparison.
///
/// This enables globally consistent validation in multi-region or
/// multi-service deployments where time offsets can otherwise cause
/// inconsistent results.
///
/// ### Example
/// ```dart
/// @InFuture()
/// final DateTime bookingDate;
///
/// // Assuming now = 2025-10-21T10:00:00Z
/// bookingDate = DateTime.utc(2025, 10, 21, 12); // ✅ Valid
/// bookingDate = DateTime.utc(2025, 10, 21, 8);  // ❌ Invalid
/// ```
///
/// ### Integration Details
/// - The validator retrieves the application timezone from
///   the [ValidationContext]'s [Environment] via:
///   ```dart
///   final zone = env.getProperty(AbstractApplicationContext.APPLICATION_TIMEZONE);
///   ```
/// - If the property exists, time comparison is delegated to
///   [ZonedDateTime] via JetLeaf’s temporal abstraction layer.
/// - Otherwise, falls back to system-local [DateTime.now()].
///
/// ### Typical Use Cases
/// - Validating **future reservation dates** or **deadlines**.
/// - Ensuring **token expirations** or **schedules** have not yet passed.
/// - Validating **release times** for delayed execution.
///
/// ### Related Constraints
/// - [InPast] — validates that a date is before the current time.
/// - [NotNull] — ensures the target value is not null before
///   applying temporal constraints.
/// - [Size] — checks that a date or numeric value falls within
///   a specified range.
///
/// ### See Also
/// - [ConstraintValidator]
/// - [ValidationContext]
/// - [Environment]
/// - [ZoneId]
/// - [ZonedDateTime]
/// {@endtemplate}
final class InFutureConstraintValidator implements ConstraintValidator<InFuture, DateTime> {
  /// Creates a new timezone-aware [InFutureConstraintValidator].
  const InFutureConstraintValidator();

  @override
  bool isValid(DateTime? value, InFuture annotation, ValidationContext context) {
    if (value == null) {
      return true;
    }

    final env = context.getEnvironment();
    final zone = env.getProperty(AbstractApplicationContext.APPLICATION_TIMEZONE);

    if (zone != null) {
      final zoneId = ZoneId.of(zone);
      return ZonedDateTime.fromDateTime(value, zoneId).isAfter(ZonedDateTime.now(zoneId));
    }

    return value.isAfter(DateTime.now());
  }
}

/// {@template jetleaf_in_past_constraint_validator}
/// A built-in **JetLeaf constraint validator** that checks whether
/// a given [DateTime] value represents a **moment in the past**, as
/// specified by the [`@InPast`] annotation.
///
/// This validator is **timezone-aware** and integrates with the active
/// [Environment] to ensure consistent temporal comparisons across
/// distributed systems. It is commonly used for validating timestamps,
/// historical records, or expiration dates.
///
/// ### Validation Rules
/// - Validation **passes** if the value is `null`.  
///   (This allows combining `@InPast` with `@NotNull` for stricter semantics.)
/// - Validation **passes** if the date/time is **strictly before** the current
///   time at validation.
/// - Validation **fails** if the date/time is **in the future** or **equal**
///   to the current moment.
///
/// ### Timezone Behavior
/// - If the [`application.timezone`] (via
///   [AbstractApplicationContext.APPLICATION_TIMEZONE]) is configured in the
///   environment, validation uses that zone for comparison.
/// - If no timezone is configured, validation defaults to the system’s local
///   [DateTime.now()] value.
///
/// ### Example
/// ```dart
/// @Target({TargetKind.fieldType})
/// @Validator(InPastConstraintValidator())
/// final class InPast extends WhenValidating {
///   const InPast({super.message = "Date must be in the past"});
/// }
///
/// class HistoricalEvent {
///   @InPast(message: "Event date must be in the past")
///   final DateTime? occurredOn;
///
///   const HistoricalEvent(this.occurredOn);
/// }
/// ```
///
/// ### Example Validation
/// | Input Value                | Result | Explanation                            |
/// |-----------------------------|--------|----------------------------------------|
/// | `null`                      | ✅ Pass | Null is ignored (nullable-friendly)     |
/// | `DateTime.now().subtract(1)`| ✅ Pass | One second ago — valid past timestamp  |
/// | `DateTime.now()`            | ❌ Fail | Equal to "now" — not considered past   |
/// | `DateTime.now().add(1)`     | ❌ Fail | Future timestamp — invalid             |
///
/// ### Execution Flow
/// 1. JetLeaf validation engine encounters an `@InPast` annotation.
/// 2. Retrieves the active [Environment] and resolves the configured timezone.
/// 3. Constructs a [ZonedDateTime] representation of the input (if applicable).
/// 4. Compares it to the current time in that zone.
/// 5. Returns `true` if `value.isBefore(now)`; otherwise, `false`.
///
/// ### Design Notes
/// - Intended for **historical** or **temporal integrity checks**.
/// - To validate future timestamps, use [`@InFuture`] instead.
/// - Always pair with [`@NotNull`] if null values are not acceptable.
/// - Uses [ZonedDateTime] for accuracy in multi-region deployments.
///
/// ### Example Violation
/// ```text
/// Property: occurredOn
/// Value: 2035-04-10T00:00:00Z
/// Constraint: @InPast
/// Message: "Event date must be in the past"
/// ```
///
/// ### See Also
/// - [InPast]
/// - [InFutureConstraintValidator]
/// - [WhenValidating]
/// - [ValidationContext]
/// - [AbstractApplicationContext]
/// - [ZonedDateTime]
/// {@endtemplate}
final class InPastConstraintValidator implements ConstraintValidator<InPast, DateTime> {
  /// {@macro jetleaf_in_past_constraint_validator}
  const InPastConstraintValidator();

  @override
  bool isValid(DateTime? value, InPast annotation, ValidationContext context) {
    if (value == null) {
      return true;
    }

    final env = context.getEnvironment();
    final zone = env.getProperty(AbstractApplicationContext.APPLICATION_TIMEZONE);

    if (zone != null) {
      final zoneId = ZoneId.of(zone);
      return ZonedDateTime.fromDateTime(value, zoneId).isBefore(ZonedDateTime.now(zoneId));
    }

    return value.isBefore(DateTime.now());
  }
}

/// {@template jetleaf_size_constraint_validator}
/// A **JetLeaf constraint validator** that ensures the annotated element’s
/// **size**, **length**, or **numeric value** lies within a specified inclusive range,
/// as defined by the [`@Size`] annotation.
///
/// This validator provides unified range validation for multiple data types,
/// including:
/// - **Strings** (character length)
/// - **Collections / Iterables** (number of elements)
/// - **Maps** (entry count)
/// - **Numbers** (numeric magnitude)
///
/// ### Validation Rules
/// - Validation **passes** if the value is `null`.  
///   (Use [`@NotNull`] in conjunction to enforce non-null values.)
/// - Validation **passes** if:
///   ```text
///   min ≤ size ≤ max
///   ```
///   where `size` depends on the data type:
///   - For strings → `value.length`
///   - For iterables → `value.length`
///   - For maps → `value.length`
///   - For numbers → `value` itself
/// - Validation **fails** otherwise.
///
/// ### Example
/// ```dart
/// @Target({TargetKind.fieldType})
/// @Validator(SizeConstraintValidator())
/// final class Size extends WhenValidating {
///   final int min;
///   final int max;
///
///   const Size({this.min = 0, this.max = double.maxFinite.toInt(), super.message = "Invalid size"});
/// }
///
/// class Product {
///   @Size(min: 3, max: 20, message: "Name must be 3–20 characters long")
///   final String name;
///
///   @Size(min: 1, max: 10, message: "Must have between 1 and 10 tags")
///   final List<String> tags;
///
///   const Product(this.name, this.tags);
/// }
/// ```
///
/// ### Example Validation
/// | Value Type | Input | Range | Result |
/// |-------------|--------|--------|---------|
/// | String | `"JetLeaf"` | 3–10 | ✅ Pass |
/// | String | `"Hi"` | 3–10 | ❌ Fail |
/// | List | `["A", "B", "C"]` | 1–5 | ✅ Pass |
/// | Map | `{a:1, b:2, c:3, d:4}` | 1–3 | ❌ Fail |
/// | Number | `8` | 5–10 | ✅ Pass |
///
/// ### Behavior Notes
/// - Supports **Strings**, **Lists**, **Sets**, **Maps**, and **numeric** types uniformly.
/// - Non-supported types are ignored and treated as valid (return `true`).
/// - Both `min` and `max` are **inclusive**.
/// - The constraint can serve as a foundation for specialized validators
///   such as `@Length`, `@Range`, or `@Between`.
///
/// ### Example Violation
/// ```text
/// Property: name
/// Value: "Hi"
/// Constraint: @Size(min: 3, max: 10)
/// Message: "Name must be 3–10 characters long"
/// ```
///
/// ### Design Notes
/// - Designed for cross-type validation consistency.
/// - Eliminates redundancy across length and range checks.
/// - Lightweight, fast, and safe to use in batch or async validation contexts.
///
/// ### See Also
/// - [Size]
/// - [InLengthConstraintValidator]
/// - [MinConstraintValidator]
/// - [MaxConstraintValidator]
/// - [NotEmptyConstraintValidator]
/// - [WhenValidating]
/// - [ValidationContext]
/// {@endtemplate}
final class SizeConstraintValidator implements ConstraintValidator<Size, Object> {
  /// {@macro jetleaf_size_constraint_validator}
  const SizeConstraintValidator();

  @override
  bool isValid(Object? value, Size annotation, ValidationContext context) {
    if (value == null) {
      return true;
    }

    num size;

    if (value is String) {
      size = value.length;
    } else if (value is Iterable) {
      size = value.length;
    } else if (value is Map) {
      size = value.length;
    } else if (value is num) {
      size = value;
    } else {
      return true;
    }

    return size.isGreaterThanOrEqualTo(annotation.min) && size.isLtOrEt(annotation.max);
  }
}

/// {@template jetleaf_max_constraint_validator}
/// A built-in **JetLeaf constraint validator** that enforces
/// upper-bound numerical limits defined by the [`@Max`] annotation.
///
/// This validator ensures that a numeric value (integer, double, or decimal)
/// does not exceed a specified maximum threshold. It is commonly used in
/// data validation scenarios such as enforcing maximum quantities,
/// rating limits, or percentage caps.
///
/// ### Validation Rules
/// - If the annotated value is `null`, validation passes automatically.
///   (Use `@NotNull` or related constraints to enforce presence.)
/// - Validation succeeds when:
///   ```text
///   value ≤ max
///   ```
/// - Validation fails when the provided value is greater than `max`.
///
/// ### Example
/// ```dart
/// @Target({TargetKind.fieldType})
/// @Constraint(MaxConstraintValidator())
/// final class Max extends WhenValidating {
///   final num value;
///
///   const Max(this.value, {super.message = "Value exceeds maximum limit"});
/// }
///
/// class Product {
///   @Max(100, message: "Discount cannot exceed 100%")
///   final num discount;
///
///   Product(this.discount);
/// }
/// ```
///
/// ### Execution Flow
/// When a property annotated with `@Max` is validated:
/// 1. JetLeaf’s validation framework detects the `@Max` constraint.
/// 2. It retrieves this [MaxConstraintValidator].
/// 3. The validator compares the field’s numeric value to the defined `max`.
/// 4. If the value is greater than the maximum, a violation is recorded
///    in the [ValidationContext].
///
/// ### Example Violation
/// ```text
/// Property: discount
/// Value: 120
/// Constraint: @Max(100)
/// Message: "Discount cannot exceed 100%"
/// ```
///
/// ### See Also
/// - [Max]
/// - [MinConstraintValidator]
/// - [ConstraintValidator]
/// - [WhenValidating]
/// - [ValidationContext]
/// {@endtemplate}
final class MaxConstraintValidator implements ConstraintValidator<Max, num> {
  /// {@macro jetleaf_max_constraint_validator}
  const MaxConstraintValidator();

  @override
  bool isValid(num? value, Max annotation, ValidationContext context) {
    if (value == null) {
      return true;
    }

    return value.isLtOrEt(annotation.value);
  }
}

/// {@template jetleaf_min_constraint_validator}
/// A built-in **JetLeaf constraint validator** that enforces
/// lower-bound numerical limits defined by the [`@Min`] annotation.
///
/// This validator ensures that a numeric value (integer, double, or decimal)
/// meets or exceeds a specified minimum threshold. It is typically applied to
/// fields such as prices, quantities, scores, and ages—anywhere a lower
/// numerical boundary must be respected.
///
/// ### Validation Rules
/// - If the annotated value is `null`, validation passes automatically.
///   (Use `@NotNull` to enforce non-nullability.)
/// - Validation succeeds when:
///   ```text
///   value ≥ min
///   ```
/// - Validation fails when the provided value is smaller than `min`.
///
/// ### Example
/// ```dart
/// @Target({TargetKind.fieldType})
/// @Constraint(MinConstraintValidator())
/// final class Min extends WhenValidating {
///   final num value;
///
///   const Min(this.value, {super.message = "Value is below minimum threshold"});
/// }
///
/// class Product {
///   @Min(1, message: "Quantity must be at least 1")
///   final int quantity;
///
///   Product(this.quantity);
/// }
/// ```
///
/// ### Execution Flow
/// When a property annotated with `@Min` is validated:
/// 1. JetLeaf’s validation framework detects the `@Min` constraint.
/// 2. It retrieves this [MinConstraintValidator].
/// 3. The validator compares the field’s numeric value to the defined `min`.
/// 4. If the value is less than the minimum, a violation is recorded
///    in the [ValidationContext].
///
/// ### Example Violation
/// ```text
/// Property: quantity
/// Value: 0
/// Constraint: @Min(1)
/// Message: "Quantity must be at least 1"
/// ```
///
/// ### See Also
/// - [Min]
/// - [MaxConstraintValidator]
/// - [ConstraintValidator]
/// - [WhenValidating]
/// - [ValidationContext]
/// {@endtemplate}
final class MinConstraintValidator implements ConstraintValidator<Min, num> {
  /// {@macro jetleaf_min_constraint_validator}
  const MinConstraintValidator();

  @override
  bool isValid(num? value, Min annotation, ValidationContext context) {
    if (value == null) {
      return true;
    }

    return value.isGtOrEt(annotation.value);
  }
}

/// {@template jetleaf_negative_constraint_validator}
/// A concrete [ConstraintValidator] implementation in **JetLeaf Validation**
/// responsible for enforcing the `@Negative` constraint on numeric fields.
///
/// The [NegativeConstraintValidator] ensures that a numeric value is
/// **strictly less than zero**. It supports all numeric subtypes including
/// `int`, `double`, and `num`.
///
/// ### Validation Rules
/// 1. **Null Values**
///    - If the validated value is `null`, the validator **returns `true`**
///      (i.e., passes validation).  
///      This behavior is consistent with JetLeaf’s composable design:
///      use `@NotNull` when you need to enforce non-null constraints.
///
/// 2. **Negative Check**
///    - The constraint passes only when the provided numeric value
///      is *strictly less than 0* (`value < 0`).
///
/// 3. **Group & Context Awareness**
///    - The [ValidationContext] parameter allows this validator to integrate
///      seamlessly with group-based validation or context-driven conditions,
///      although it is not directly used in this particular implementation.
///
/// ### Example
/// ```dart
/// @Target({TargetKind.fieldType})
/// @Constraint(NegativeConstraintValidator())
/// class Negative extends WhenValidating {
///   const Negative();
/// }
///
/// class Transaction {
///   @Negative(message: 'Refund amount must be negative')
///   final double refundAmount;
///
///   Transaction(this.refundAmount);
/// }
/// ```
///
/// ### Behavior
/// | Input Value | Valid? | Explanation                        |
/// |--------------|--------|------------------------------------|
/// | `-1`         | ✅     | Negative number passes              |
/// | `0`          | ❌     | Zero is not considered negative     |
/// | `1.5`        | ❌     | Positive number fails validation    |
/// | `null`       | ✅     | Null is ignored (use `@NotNull`)    |
///
/// ### Design Notes
/// - **Numeric Agnostic:** Works with any `num` type — including `int` and `double`.
/// - **Null-Safe:** Designed for optional validation with composable constraints.
/// - **Context-Compatible:** Integrates with [ValidationContext] for
///   conditional and grouped validation scenarios.
/// - **Simple and Efficient:** Uses direct comparison (`value < 0`) for accuracy.
///
/// ### See Also
/// - [ConstraintValidator]
/// - [Negative]
/// - [ValidationContext]
/// - [WhenValidating]
/// - [NotNull]
/// {@endtemplate}
final class NegativeConstraintValidator implements ConstraintValidator<Negative, num> {
  /// {@macro jetleaf_negative_constraint_validator}
  const NegativeConstraintValidator();

  @override
  bool isValid(num? value, Negative annotation, ValidationContext context) {
    if (value == null) {
      return true;
    }

    return value.isLessThan(0);
  }
}

/// {@template jetleaf_positive_constraint_validator}
/// A **JetLeaf constraint validator** that ensures a numeric value
/// is **strictly greater than zero**, as defined by the [`@Positive`] annotation.
///
/// This validator is used to enforce **positivity constraints** on numeric
/// fields, parameters, or computed values, helping ensure correctness in
/// domains such as finance, inventory, resource quotas, and measurement systems.
///
/// ### Validation Rules
/// - Validation **passes** if the value is `null`.  
///   (This allows composability with [`@NotNull`] when non-null enforcement is needed.)
/// - Validation **passes** if the numeric value `>` `0`.
/// - Validation **fails** if the value is `≤ 0` (including negative numbers and zero).
///
/// ### Example
/// ```dart
/// @Target({TargetKind.fieldType})
/// @Validator(PositiveConstraintValidator())
/// final class Positive extends WhenValidating {
///   const Positive({super.message = "Value must be positive"});
/// }
///
/// class Payment {
///   @Positive(message: "Amount must be greater than zero")
///   final double amount;
///
///   const Payment(this.amount);
/// }
/// ```
///
/// ### Example Validation
/// | Input Value | Result |
/// |-------------|---------|
/// | `42`        | ✅ Pass |
/// | `0`         | ❌ Fail |
/// | `-10`       | ❌ Fail |
/// | `null`      | ✅ Pass |
///
/// ### Behavior Notes
/// - Only enforces **strict positivity**; use [`@PositiveOrZero`] if zero should be accepted.
/// - Applies to all [num] subtypes (`int`, `double`, `Decimal`, etc.).
/// - To reject `null` values, pair with [`@NotNull`].
/// - Floating-point precision is preserved through native numeric comparison.
/// - Can be applied at both **field** and **parameter** levels.
///
/// ### Example Violation
/// ```text
/// Property: amount
/// Value: 0
/// Constraint: @Positive
/// Message: "Amount must be greater than zero"
/// ```
///
/// ### Design Notes
/// - Ideal for **financial**, **inventory**, and **validation-layer** checks.
/// - Lightweight, side-effect-free, and suitable for synchronous or batch validation.
/// - Serves as a building block for more complex domain constraints
///   (e.g., `@PositiveBalance`, `@PositivePrice`).
///
/// ### See Also
/// - [Positive]
/// - [PositiveOrZeroConstraintValidator]
/// - [NotNullConstraintValidator]
/// - [WhenValidating]
/// - [ValidationContext]
/// {@endtemplate}
final class PositiveConstraintValidator implements ConstraintValidator<Positive, num> {
  /// {@macro jetleaf_positive_constraint_validator}
  const PositiveConstraintValidator();

  @override
  bool isValid(num? value, Positive annotation, ValidationContext context) {
    if (value == null) {
      return true;
    }

    return value.isGreaterThan(0);
  }
}

/// {@template jetleaf_not_blank_constraint_validator}
/// A built-in **JetLeaf constraint validator** that ensures
/// a string value is **not blank**, as defined by the [`@NotBlank`] annotation.
///
/// This validator enforces that the value:
/// - Is **not null**.
/// - Contains at least one **non-whitespace** character.
///
/// Unlike [`@NotEmpty`], which only checks that the string length is greater than zero,
/// `@NotBlank` also trims whitespace, preventing values like `"   "` from passing validation.
///
/// ### Validation Rules
/// - Validation **fails** if the value is `null` or consists only of whitespace.
/// - Validation **succeeds** if the trimmed value has one or more visible characters.
///
/// ### Example
/// ```dart
/// @Target({TargetKind.fieldType})
/// @Constraint(NotBlankConstraintValidator())
/// final class NotBlank extends WhenValidating {
///   const NotBlank({super.message = "Field must not be blank"});
/// }
///
/// class UserRegistration {
///   @NotBlank(message: "Username is required")
///   final String username;
///
///   const UserRegistration(this.username);
/// }
/// ```
///
/// ### Example Validation
/// | Input Value     | Result  | Explanation                     |
/// |-----------------|----------|----------------------------------|
/// | `"JohnDoe"`     | ✅ Pass  | Non-empty, non-whitespace       |
/// | `"  John  "`    | ✅ Pass  | Trimmed result is not empty     |
/// | `"    "`        | ❌ Fail  | Only whitespace characters      |
/// | `null`          | ❌ Fail  | Null values are not permitted   |
///
/// ### Execution Flow
/// 1. The JetLeaf validation engine encounters a property annotated with `@NotBlank`.
/// 2. It instantiates or retrieves this [NotBlankConstraintValidator].
/// 3. The value is checked for `null` and trimmed.
/// 4. If the trimmed string is empty, the validator marks a violation in the [ValidationContext].
///
/// ### Example Violation
/// ```text
/// Property: username
/// Value: "   "
/// Constraint: @NotBlank
/// Message: "Username is required"
/// ```
///
/// ### Design Notes
/// - `@NotBlank` is stricter than `@NotEmpty` and ideal for validating textual input.
/// - Works seamlessly with other annotations such as `@Email` or `@Size`.
/// - The check is purely local — it does not rely on environment configuration
///   provided by [ValidationContext].
///
/// ### See Also
/// - [NotBlank]
/// - [NotEmptyConstraintValidator]
/// - [ConstraintValidator]
/// - [WhenValidating]
/// - [ValidationContext]
/// {@endtemplate}
final class NotBlankConstraintValidator implements ConstraintValidator<NotBlank, String> {
  /// {@macro jetleaf_not_blank_constraint_validator}
  const NotBlankConstraintValidator();

  @override
  bool isValid(String? value, NotBlank annotation, ValidationContext context) {
    if (value == null) {
      return false;
    }

    return value.trim().isNotEmpty;
  }
}

/// {@template jetleaf_not_empty_constraint_validator}
/// A built-in **JetLeaf constraint validator** that ensures a value
/// is **not empty**, as defined by the [`@NotEmpty`] annotation.
///
/// This validator provides a generic, type-flexible emptiness check
/// for multiple data types commonly used in JetLeaf applications.
///
/// ### Validation Rules
/// - Validation **fails** if the value is `null`.
/// - Validation **fails** if:
///   - The value is a `String` that has a length of `0`.
///   - The value is an `Iterable` (e.g., `List`, `Set`) that has no elements.
///   - The value is a `Map` with no entries.
/// - Validation **succeeds** for all other non-null values, including
///   primitives, numbers, and complex objects.
///
/// ### Supported Types
/// | Type       | Check Applied                |
/// |-------------|------------------------------|
/// | `String`    | `isNotEmpty`                 |
/// | `Iterable`  | `isNotEmpty`                 |
/// | `Map`       | `isNotEmpty`                 |
/// | `Object`    | Always considered **valid**  |
///
/// ### Example
/// ```dart
/// @Target({TargetKind.fieldType})
/// @Constraint(NotEmptyConstraintValidator())
/// final class NotEmpty extends WhenValidating {
///   const NotEmpty({super.message = "Field must not be empty"});
/// }
///
/// class RegistrationForm {
///   @NotEmpty(message: "Email address cannot be empty")
///   final String email;
///
///   @NotEmpty(message: "You must select at least one role")
///   final List<String> roles;
///
///   const RegistrationForm(this.email, this.roles);
/// }
/// ```
///
/// ### Example Validation
/// | Input Value   | Result | Explanation                   |
/// |----------------|--------|--------------------------------|
/// | `"Alice"`      | ✅ Pass | Non-empty string              |
/// | `""`           | ❌ Fail | Empty string                  |
/// | `[1, 2, 3]`    | ✅ Pass | Iterable with elements        |
/// | `[]`           | ❌ Fail | Empty iterable                |
/// | `{}`           | ❌ Fail | Empty map                     |
/// | `{"a": 1}`     | ✅ Pass | Non-empty map                 |
/// | `42`           | ✅ Pass | Non-collection, non-null value|
/// | `null`         | ❌ Fail | Null values are not permitted |
///
/// ### Execution Flow
/// 1. The JetLeaf validation engine encounters a property annotated with `@NotEmpty`.
/// 2. It invokes [NotEmptyConstraintValidator.isValid].
/// 3. The validator checks whether the value is `null` or empty based on type.
/// 4. If the value fails the check, the associated constraint violation is recorded.
///
/// ### Design Notes
/// - `@NotEmpty` is **less strict** than [`@NotBlank`], as it does not trim or inspect whitespace.
/// - Ideal for collections, lists, maps, and general data structures.
/// - When applied to a `String`, it ensures only that the string is not empty—whitespace-only values still pass.
/// - Purely local; this validator does not depend on [ValidationContext] or environmental configuration.
///
/// ### Example Violation
/// ```text
/// Property: roles
/// Value: []
/// Constraint: @NotEmpty
/// Message: "You must select at least one role"
/// ```
///
/// ### See Also
/// - [NotEmpty]
/// - [NotBlankConstraintValidator]
/// - [ConstraintValidator]
/// - [WhenValidating]
/// - [ValidationContext]
/// {@endtemplate}
final class NotEmptyConstraintValidator implements ConstraintValidator<NotEmpty, Object> {
  /// {@macro jetleaf_not_empty_constraint_validator}
  const NotEmptyConstraintValidator();

  @override
  bool isValid(Object? value, NotEmpty annotation, ValidationContext context) {
    if (value == null) {
      return false;
    }
    
    if (value is String) {
      return value.isNotEmpty;
    }

    if (value is Iterable) {
      return value.isNotEmpty;
    }

    if (value is Map) {
      return value.isNotEmpty;
    }

    return true;
  }
}

/// {@template jetleaf_not_null_constraint_validator}
/// A built-in **JetLeaf constraint validator** that ensures a value
/// is **not null**, as defined by the [`@NotNull`] annotation.
///
/// This validator enforces the fundamental invariant that a
/// property, parameter, or field **must be provided** (i.e., not `null`)
/// at runtime. It is one of the most basic and commonly used
/// constraints in the JetLeaf validation system.
///
/// ### Validation Rules
/// - Validation **fails** if the value is `null`.
/// - Validation **succeeds** for all non-null values, regardless of type.
///
/// ### Supported Types
/// This constraint applies universally to **all object types** —
/// `String`, `num`, `bool`, `Iterable`, `Map`, `DateTime`, and any
/// user-defined class.  
/// The validator **does not** perform emptiness or content checks;
/// for that, see [`@NotEmpty`] or [`@NotBlank`].
///
/// ### Example
/// ```dart
/// @Target({TargetKind.fieldType})
/// @Constraint(NotNullConstraintValidator())
/// final class NotNull extends WhenValidating {
///   const NotNull({super.message = "Value cannot be null"});
/// }
///
/// class UserProfile {
///   @NotNull(message: "Username must not be null")
///   final String? username;
///
///   @NotNull(message: "Created date must be set")
///   final DateTime? createdAt;
///
///   const UserProfile(this.username, this.createdAt);
/// }
/// ```
///
/// ### Example Validation
/// | Input Value    | Result | Explanation                    |
/// |-----------------|--------|--------------------------------|
/// | `"Alice"`       | ✅ Pass | Non-null string                |
/// | `""`            | ✅ Pass | Empty string, but non-null     |
/// | `[1, 2, 3]`     | ✅ Pass | Non-null list                  |
/// | `null`          | ❌ Fail | Null values are disallowed     |
/// | `0`             | ✅ Pass | Numeric zero is valid          |
///
/// ### Execution Flow
/// 1. The JetLeaf validation engine detects a property annotated with `@NotNull`.
/// 2. It invokes [NotNullConstraintValidator.isValid].
/// 3. The validator performs a simple null check on the value.
/// 4. If `value == null`, a validation violation is recorded with the annotation’s message.
///
/// ### Design Notes
/// - This validator performs **no type checking** or content analysis.
/// - Use [`@NotEmpty`] to check for non-empty collections or strings.
/// - Use [`@NotBlank`] to ensure non-whitespace-only strings.
/// - Often used in conjunction with other annotations for compound validation,
///   e.g.:
///   ```dart
///   @NotNull()
///   @Size(min: 1, max: 10)
///   final int priority;
///   ```
///
/// ### Example Violation
/// ```text
/// Property: username
/// Value: null
/// Constraint: @NotNull
/// Message: "Username must not be null"
/// ```
///
/// ### See Also
/// - [NotNull]
/// - [NotEmptyConstraintValidator]
/// - [NotBlankConstraintValidator]
/// - [ConstraintValidator]
/// - [WhenValidating]
/// - [ValidationContext]
/// {@endtemplate}
final class NotNullConstraintValidator implements ConstraintValidator<NotNull, Object> {
  /// {@macro jetleaf_not_null_constraint_validator}
  const NotNullConstraintValidator();

  @override
  bool isValid(Object? value, NotNull annotation, ValidationContext context) => value != null;
}

/// {@template jetleaf_pattern_constraint_validator}
/// A **JetLeaf constraint validator** that verifies whether a given [String]
/// value matches a **regular expression pattern**, as defined by the
/// [`@Pattern`] annotation.
///
/// This validator enables fine-grained control over text formats such as
/// email addresses, UUIDs, phone numbers, identifiers, and any other
/// user-defined pattern-based validations.
///
/// ### Validation Rules
/// - Validation **passes** if the value is `null`.  
///   (This allows nullable semantics and compatibility with `@NotNull`. )
/// - Validation **passes** if the provided [RegExp] pattern **matches** the
///   entire string (via [RegExp.hasMatch]).
/// - Validation **fails** if the string does **not match** the given pattern.
///
/// ### Example
/// ```dart
/// @Target({TargetKind.fieldType})
/// @Validator(PatternConstraintValidator())
/// final class Pattern extends WhenValidating {
///   final String pattern;
///
///   const Pattern(this.pattern, {super.message = "Value does not match pattern"});
/// }
///
/// class UserAccount {
///   @Pattern(r'^[a-zA-Z0-9_]{3,16}$',
///     message: "Username must be 3–16 characters, letters/numbers only")
///   final String username;
///
///   const UserAccount(this.username);
/// }
/// ```
///
/// ### Example Validation
/// | Input Value       | Pattern                   | Result |
/// |-------------------|---------------------------|--------|
/// | `"alex_01"`       | `^[a-zA-Z0-9_]{3,16}$`    | ✅ Pass |
/// | `"al"`            | `^[a-zA-Z0-9_]{3,16}$`    | ❌ Fail |
/// | `"alex!!"`        | `^[a-zA-Z0-9_]{3,16}$`    | ❌ Fail |
/// | `null`            | any pattern               | ✅ Pass |
///
/// ### Behavior Notes
/// - Uses Dart’s [RegExp] engine; patterns follow standard ECMAScript syntax.
/// - To require non-null values before applying the regex, pair with [`@NotNull`].
/// - Use raw string literals (`r'...'`) to avoid double escaping backslashes.
/// - Designed for **field-level** constraints; can also be used for custom DTO validations.
///
/// ### Example Violation
/// ```text
/// Property: username
/// Value: alex!!
/// Constraint: @Pattern
/// Pattern: ^[a-zA-Z0-9_]{3,16}$
/// Message: "Username must be 3–16 characters, letters/numbers only"
/// ```
///
/// ### Design Notes
/// - Ideal for enforcing **syntactic constraints** without custom logic.
/// - Lightweight and reusable across domain models.
/// - Can serve as a base for specialized pattern validators (e.g. `@Email`, `@UUID`).
///
/// ### See Also
/// - [Pattern]
/// - [NotNullConstraintValidator]
/// - [EmailConstraintValidator]
/// - [WhenValidating]
/// - [ValidationContext]
/// {@endtemplate}
final class PatternConstraintValidator implements ConstraintValidator<Pattern, String> {
  /// {@macro jetleaf_pattern_constraint_validator}
  const PatternConstraintValidator();

  @override
  bool isValid(String? value, Pattern annotation, ValidationContext context) {
    if (value == null) {
      return true;
    }

    return RegExp(annotation.regexp).hasMatch(value);
  }
}