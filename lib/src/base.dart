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

import 'package:jetleaf_core/intercept.dart';
import 'package:jetleaf_lang/lang.dart';
import 'package:jetleaf_env/env.dart';

import 'annotations.dart';

/// {@template constraint_validator}
/// A foundational **JetLeaf Validation API** contract that defines how
/// custom validation logic is applied to annotated elements.
///
/// The `ConstraintValidator` interface bridges annotation-based constraints
/// with runtime validation behavior. Each implementation of this interface
/// handles a specific annotation type and defines how to validate a particular
/// kind of value.
///
/// ### Purpose
/// `ConstraintValidator` enables the declarative definition of validation
/// rules using annotations, ensuring separation between *constraint definition*
/// (via annotations) and *constraint enforcement* (via validator logic).
///
/// For example, a `@NotEmpty` annotation may be paired with a
/// `NotEmptyValidator` that implements this interface and checks
/// whether the provided value is not `null` or empty.
///
/// ### Type Parameters
/// - **A** – The annotation type that triggers this validator.
///   Must extend [WhenValidating] to support JetLeaf’s reflection system.
/// - **T** – The type of value that this validator inspects.
///
/// ### Core Contract
/// Implementations must provide logic for the [isValid] method, which performs
/// the actual validation of the provided value against the metadata declared
/// in the annotation.
///
/// ```dart
/// @override
/// bool isValid(T value, A annotation);
/// ```
///
/// - Returns `true` if the value satisfies the constraint.
/// - Returns `false` if the value violates the constraint.
///
/// ### Example
/// ```dart
/// @Target({TargetKind.fieldType})
/// class NotEmpty extends WhenValidating {
///   const NotEmpty();
/// }
///
/// class NotEmptyValidator implements ConstraintValidator<NotEmpty, String> {
///   @override
///   bool isValid(String value, NotEmpty annotation) {
///     return value.isNotEmpty;
///   }
/// }
/// ```
///
/// ### Usage in the JetLeaf Validation Framework
/// The JetLeaf validation engine automatically discovers and associates
/// validators with their corresponding annotations at runtime. When a field,
/// parameter, or property is annotated, JetLeaf locates the matching
/// `ConstraintValidator` and invokes [isValid] during validation.
///
/// ```dart
/// final validator = context.getValidatorFor<NotEmpty, String>();
/// final isValid = validator.isValid("Hello", const NotEmpty());
/// ```
///
/// ### Advanced Scenarios
/// - **Cross-Field Validation:** Validators can access additional context
///   (such as the containing object) if integrated with a composite validator.
/// - **Parameterized Annotations:** Custom annotations may expose parameters
///   (e.g., `@Size(min: 3, max: 10)`) that validators interpret during validation.
/// - **Compositional Constraints:** Multiple validators can be applied to the
///   same target for compound constraint evaluation.
///
/// ### See Also
/// - [WhenValidating]
/// - [ConstraintViolation]
/// - [ValidatorRegistry]
/// - [ValidationContext]
///
/// ### Notes
/// - Validators **must be stateless** or thread-safe.  
/// - Implementations should gracefully handle `null` values where applicable.  
/// - For cross-field validation, consider extending a contextual validator base class.  
/// - JetLeaf automatically associates validators via annotation reflection,
///   so no explicit registration is usually required.
/// {@endtemplate}
@Generic(ConstraintValidator)
abstract interface class ConstraintValidator<A extends WhenValidating, T> {
  /// {@macro constraint_validator}
  const ConstraintValidator();

  /// Evaluates whether [value] satisfies the constraint defined by [annotation].
  ///
  /// Returns:
  /// - `true` if the value complies with the constraint.
  /// - `false` if the value violates it.
  ///
  /// Implementations should assume that [annotation] carries any necessary
  /// configuration metadata (for example, minimum or maximum values, patterns,
  /// or custom messages) required to perform validation.
  ///
  /// **Example:**
  /// ```dart
  /// bool isValid(String value, Size annotation) {
  ///   return value.length >= annotation.min && value.length <= annotation.max;
  /// }
  /// ```
  bool isValid(T? value, A annotation, ValidationContext context);
}

/// {@template jetleaf_constraint_violation}
/// Represents a **single validation failure** detected during constraint
/// evaluation.
///
/// A [ConstraintViolation] encapsulates all contextual information about a
/// failed validation rule, including:
/// - The **property path** (e.g., `"user.email"`)
/// - The **invalid value**
/// - The **source element** where the failure occurred (field, method, or parameter)
/// - The **message** associated with the violated constraint
/// - The **constraint annotation** definition
/// - The **validation groups** and **payloads** involved
///
/// ### Purpose
/// JetLeaf’s validation engine generates instances of [ConstraintViolation]
/// whenever a [ConstraintValidator] returns `false` during evaluation.
/// Each violation entry provides rich metadata to support:
/// - Error reporting
/// - API response mapping
/// - Context-aware exception generation (e.g. [ConstraintViolationException])
///
/// ### Example
/// ```dart
/// final violations = report.getViolations();
/// for (final v in violations) {
///   print('Violation at ${v.getPropertyPath()}: ${v.getMessage()}');
/// }
/// ```
///
/// ### Example Output
/// ```text
/// Violation at user.email: must be a valid email address
/// Violation at bookingDate: must be in the future
/// ```
///
/// ### Typical Usage
/// - Accessed from a [ValidationReport] after validation completes.
/// - Included in [ConstraintViolationException] for structured error reporting.
/// - Used in UI form validation or API-level validation feedback.
///
/// ### Design Notes
/// - This is an **interface**, not a concrete implementation.
/// - Implementations (e.g., `DetailedConstraintViolation`) must override
///   equality and hashing for deterministic comparisons via [EqualsAndHashCode].
/// - Supports grouping and payload semantics defined in JetLeaf’s constraint model.
///
/// ### See Also
/// - [ConstraintViolationException]
/// - [ValidationReport]
/// - [ConstraintValidator]
/// - [DetailedConstraintViolation]
/// - [ConstraintPayload]
/// {@endtemplate}
abstract interface class ConstraintViolation with EqualsAndHashCode {
  /// The **property path** where the violation occurred.
  ///
  /// Represents the fully qualified path to the violated element, such as:
  /// - `"user.email"` for a field violation.
  /// - `"OrderService.placeOrder.totalAmount"` for a nested parameter.
  ///
  /// Useful for rendering clear, hierarchical validation messages.
  String getPropertyPath();

  /// The **invalid value** that triggered this constraint violation.
  ///
  /// May be `null` for constraints such as `@NotNull` or `@NotEmpty`.
  /// The value is returned exactly as provided to the validator.
  Object? getInvalidValue();

  /// The **source element** associated with the violation.
  ///
  /// This can represent:
  /// - A [Class] (type-level validation)
  /// - A [Method] (return or parameter validation)
  /// - A [Parameter] (argument-level validation)
  ///
  /// Enables reflective inspection and precise violation localization.
  Source getSource();

  /// The **human-readable message** describing the violation.
  ///
  /// Usually defined in the constraint annotation’s `message` attribute,
  /// potentially resolved via internationalization or message interpolation.
  String getMessage();

  /// The **constraint annotation** instance that triggered the violation.
  ///
  /// Examples include:
  /// - [`@NotEmpty`]
  /// - [`@NotNull`]
  /// - [`@InFuture`]
  ///
  /// Enables introspection of metadata such as message templates,
  /// custom attributes, or severity.
  ReflectableAnnotation getConstraintAnnotation();

  /// The **validation groups** that this violation belongs to.
  ///
  /// Groups determine the activation scope of constraints during validation.
  /// Useful when performing partial or conditional validations.
  Set<Class> getGroups();

  /// The **payloads** attached to this violation.
  ///
  /// Payloads can carry additional metadata for integration with frameworks
  /// or message resolvers. For example, UI-specific hints or logging codes.
  Set<ConstraintPayload> getPayloads();
}

/// {@template jetleaf_validation_report}
/// Represents the **result of a validation process**, encapsulating all
/// [ConstraintViolation]s detected during execution.
///
/// A [ValidationReport] provides structured access to validation outcomes,
/// allowing clients to:
/// - Determine overall validity status.
/// - Retrieve all violations or those scoped to a specific property.
/// - Access the first violation message for quick feedback.
///
/// ### Purpose
/// JetLeaf’s validation engine returns a [ValidationReport] whenever validation
/// is performed—either through:
/// - Object-level validation (via [Validator.validate])
/// - Property-level validation (via [Validator.validateProperty])
/// - Executable validation (via [ExecutableValidator])
///
/// This abstraction decouples validation results from exception handling,
/// allowing fine-grained inspection before raising a [ConstraintViolationException].
///
/// ### Example
/// ```dart
/// final report = validator.validate(user, user.getClass());
///
/// if (!report.isValid()) {
///   print("Validation failed:");
///   for (final v in report.getViolations()) {
///     print(" - ${v.getPropertyPath()}: ${v.getMessage()}");
///   }
/// }
/// ```
///
/// ### Example Output
/// ```text
/// Validation failed:
///  - email: must be a valid email address
///  - password: must contain at least 8 characters
/// ```
///
/// ### Design Notes
/// - Implementations (e.g., [SimpleValidationReport]) should be **immutable**
///   and implement [EqualsAndHashCode] for deterministic comparisons.
/// - Reports can be empty (no violations), in which case [isValid] returns `true`.
/// - Intended to be easily serializable for APIs or UI feedback systems.
///
/// ### Typical Implementations
/// - [SimpleValidationReport] — in-memory, immutable collection of violations.
/// - [DetailedValidationReport] — extended version including contextual metadata.
///
/// ### See Also
/// - [ConstraintViolation]
/// - [ConstraintViolationException]
/// - [Validator]
/// - [ExecutableValidator]
/// {@endtemplate}
abstract interface class ValidationReport with EqualsAndHashCode {
  /// Whether validation **passed successfully** (i.e., no violations detected).
  ///
  /// ### Returns
  /// - `true` if `getViolations()` is empty.
  /// - `false` otherwise.
  ///
  /// ### Example
  /// ```dart
  /// if (report.isValid()) {
  ///   print("Object is valid!");
  /// }
  /// ```
  bool isValid();

  /// Returns **all constraint violations** discovered during validation.
  ///
  /// Each violation represents an individual rule failure detected by a
  /// [ConstraintValidator].
  ///
  /// ### Example
  /// ```dart
  /// final violations = report.getViolations();
  /// for (final v in violations) {
  ///   print("${v.getPropertyPath()}: ${v.getMessage()}");
  /// }
  /// ```
  Set<ConstraintViolation> getViolations();

  /// Returns all violations that occurred for a specific **property path**.
  ///
  /// This enables property-scoped validation feedback—useful for UI
  /// components, API responses, or field-level diagnostics.
  ///
  /// ### Example
  /// ```dart
  /// final emailErrors = report.getViolationsForProperty("email");
  /// if (emailErrors.isNotEmpty) {
  ///   print(emailErrors.first.getMessage());
  /// }
  /// ```
  Set<ConstraintViolation> getViolationsForProperty(String propertyPath);

  /// Returns the **first violation message**, or `null` if no violations exist.
  ///
  /// Useful for quick feedback scenarios where only one message is needed,
  /// such as form validation or logging summaries.
  ///
  /// ### Example
  /// ```dart
  /// print(report.getFirstViolationMessage() ?? "All constraints passed!");
  /// ```
  String? getFirstViolationMessage();
}

/// {@template jetleaf_executable_validator}
/// Defines the contract for **method-level validation**, providing APIs to
/// validate both **parameters** and **return values** of executable members
/// (methods, constructors, etc.).
///
/// This interface forms the foundation of **JetLeaf’s method interception
/// validation layer**, allowing annotations such as `@Valid`, `@Validated`,
/// or custom constraint annotations to be applied directly to method
/// parameters or return types.
///
/// ### Purpose
/// - Ensure input arguments to a method satisfy declared constraints before execution.
/// - Verify that the method’s return value adheres to postconditions after execution.
/// - Integrate seamlessly with AOP-style interceptors (see
///   [AbstractValidationInterceptor]).
///
/// ### Example
/// ```dart
/// class UserService {
///   @NotNull()
///   User createUser(@Valid() User user) {
///     // ...
///   }
/// }
///
/// final validator = MyExecutableValidator();
/// final method = UserService.getClass().getMethod('createUser');
///
/// // Validate parameters before method call
/// final paramReport = validator.validateParameters(
///   service,
///   method,
///   MethodArgument([user]),
/// );
///
/// // Validate return value after call
/// final result = service.createUser(user);
/// final returnReport = validator.validateReturnValue(
///   service,
///   method,
///   result,
/// );
/// ```
///
/// ### Typical Use in AOP Pipelines
/// The [AbstractValidationInterceptor] integrates [ExecutableValidator]s
/// into method invocation flows:
///
/// - `validateParameters` is invoked *before* method execution.
/// - `validateReturnValue` is invoked *after* method execution (only if successful).
///
/// ### Design Notes
/// - Implementations must not throw by default; instead, return a
///   [ValidationReport].
/// - If violations exist, consumers (e.g. interceptors) may raise a
///   [ConstraintViolationException].
/// - Parameter-level validation supports nested pods through `@Valid`.
///
/// ### See Also
/// - [Validator]
/// - [AbstractExecutableValidator]
/// - [ConstraintViolation]
/// - [ValidationReport]
/// - [AbstractValidationInterceptor]
/// {@endtemplate}
abstract interface class ExecutableValidator {
  /// Validates all **parameters** of the given [method] against their
  /// associated constraint annotations.
  ///
  /// ### Parameters
  /// - [target]: The object instance on which the method is being invoked.
  /// - [method]: The executable (method or constructor) being validated.
  /// - [arguments]: Optional wrapper for method arguments (if not provided,
  ///   implementations may reflectively extract parameter values).
  /// - [groups]: Optional active validation groups determining which
  ///   constraints are applied.
  ///
  /// ### Returns
  /// A [ValidationReport] detailing all parameter constraint violations.
  ///
  /// ### Example
  /// ```dart
  /// final report = validator.validateParameters(
  ///   service,
  ///   method,
  ///   MethodArgument(["testUser"]),
  /// );
  /// if (!report.isValid()) throw ConstraintViolationException(report);
  /// ```
  ValidationReport validateParameters(
    Object target,
    Method method, [
    MethodArgument? arguments,
    Set<Class>? groups,
  ]);

  /// Validates the **return value** of a method after successful execution.
  ///
  /// This method ensures that the returned object satisfies all constraints
  /// applied to the method’s return type (e.g., `@NotNull` on return).
  ///
  /// ### Parameters
  /// - [target]: The object instance on which the method was executed.
  /// - [method]: The executable whose return value is being validated.
  /// - [returnValue]: The actual value returned by the method.
  /// - [groups]: Optional active validation groups determining which
  ///   constraints are applied.
  ///
  /// ### Returns
  /// A [ValidationReport] containing any return value constraint violations.
  ///
  /// ### Example
  /// ```dart
  /// final result = service.processData();
  /// final report = validator.validateReturnValue(service, method, result);
  /// if (!report.isValid()) throw ConstraintViolationException(report);
  /// ```
  ValidationReport validateReturnValue(
    Object target,
    Method method,
    Object? returnValue, [
    Set<Class>? groups,
  ]);
}

/// {@template jetleaf_validator}
/// Defines the contract for **pod validation** at the object and property level.
///
/// A [Validator] is responsible for performing constraint checks on entire
/// objects, their individual properties, or any nested pods marked as `@Valid`.
/// This is the entry point for most validation workflows within the JetLeaf
/// validation subsystem.
///
/// ### Purpose
/// - Validate all fields of a class against their declared constraint annotations.
/// - Validate a single property (field) by name.
/// - Provide access to an [ExecutableValidator] for method-level validation.
/// - Support validation groups for contextual or phased validation flows.
///
/// ### Typical Usage
/// ```dart
/// final user = User(name: '', age: -1);
/// final validator = MyValidator();
///
/// // Validate the entire object
/// final report = validator.validate(user, User.getClass());
///
/// if (!report.isValid()) {
///   throw ConstraintViolationException(report);
/// }
///
/// // Validate a specific property
/// final nameReport = validator.validateProperty(user, User.getClass(), 'name');
///
/// // Validate method parameters or return values
/// final execValidator = validator.forExecutables();
/// final method = UserService.getClass().getMethod('registerUser');
/// final execReport = execValidator.validateParameters(service, method);
/// ```
///
/// ### Design Notes
/// - Implementations may use reflection to inspect fields, annotations, and
///   nested constraints.
/// - Validation groups (via [Set<Class>]) determine which constraints apply.
/// - Violations are returned in a [ValidationReport], which can later be used
///   to raise a [ConstraintViolationException].
///
/// ### See Also
/// - [ExecutableValidator]
/// - [ValidationReport]
/// - [ConstraintViolation]
/// - [ConstraintViolationException]
/// - [AbstractValidator]
/// {@endtemplate}
abstract interface class Validator {
  /// Validates all constraints defined on the given [target] object.
  ///
  /// This method recursively evaluates every field (and nested pods annotated
  /// with `@Valid`) to detect constraint violations.
  ///
  /// ### Parameters
  /// - [target]: The object instance to validate.
  /// - [targetClass]: Optional class metadata; if omitted, it is resolved via reflection.
  /// - [groups]: Optional active validation groups controlling which constraints apply.
  ///
  /// ### Returns
  /// A [ValidationReport] containing all detected violations, or an empty report
  /// if validation succeeds.
  ///
  /// ### Example
  /// ```dart
  /// final report = validator.validate(user, User.getClass());
  /// if (!report.isValid()) throw ConstraintViolationException(report);
  /// ```
  ValidationReport validate(
    Object target,
    Class? targetClass, [
    Set<Class>? groups,
  ]);

  /// Validates the constraints applied to a specific property (field) of [target].
  ///
  /// This method is typically used for targeted checks, such as validating a
  /// single input field in a form without validating the entire object.
  ///
  /// ### Parameters
  /// - [target]: The object instance containing the property.
  /// - [targetClass]: Optional class metadata; if omitted, it is inferred from [target].
  /// - [propertyName]: The name of the property (field) to validate.
  /// - [groups]: Optional validation groups to control which constraints apply.
  ///
  /// ### Returns
  /// A [ValidationReport] containing violations for the specified property,
  /// or an empty report if no violations were found.
  ///
  /// ### Example
  /// ```dart
  /// final report = validator.validateProperty(user, null, 'email');
  /// ```
  ValidationReport validateProperty(
    Object target,
    Class? targetClass,
    String propertyName, [
    Set<Class>? groups,
  ]);

  /// Returns an [ExecutableValidator] capable of validating method parameters
  /// and return values for this validator.
  ///
  /// This allows integration with AOP-based validation interceptors, enabling
  /// declarative validation of service or controller methods.
  ///
  /// ### Returns
  /// An [ExecutableValidator] bound to this validator’s environment.
  ///
  /// ### Example
  /// ```dart
  /// final execValidator = validator.forExecutables();
  /// final report = execValidator.validateParameters(service, method);
  /// ```
  ExecutableValidator forExecutables();
}

/// {@template jetleaf_validation_context}
/// Represents the **execution context** for constraint validation.
///
/// A [ValidationContext] provides runtime dependencies and environmental access
/// needed during validation, such as configuration, localization, or dependency
/// resolution. It is typically passed into [ConstraintValidator] instances when
/// validating values.
///
/// ### Purpose
/// - Provide access to the active [Environment] (e.g., application, testing, or
///   custom runtime environments).
/// - Support integration with dependency injection or contextual services.
/// - Allow advanced validators to adapt behavior dynamically based on the
///   environment (e.g., locale-specific messages or environment-aware checks).
///
/// ### Example
/// ```dart
/// class NotEmptyValidator implements ConstraintValidator<String, NotEmpty> {
///   @override
///   bool isValid(String? value, NotEmpty annotation, ValidationContext context) {
///     final env = context.getEnvironment();
///     // Use environment for message resolution or configuration
///     return value?.trim().isNotEmpty ?? false;
///   }
/// }
/// ```
///
/// ### Design Notes
/// - Implementations may wrap additional context (e.g., message resolvers,
///   metadata providers, dependency containers).
/// - Typically created via `SimpleValidationContext` or framework-specific
///   factories within validators like [AbstractExecutableValidator].
///
/// ### See Also
/// - [ConstraintValidator]
/// - [AbstractExecutableValidator]
/// - [Environment]
/// {@endtemplate}
abstract interface class ValidationContext {
  /// Returns the active [Environment] associated with this validation process.
  ///
  /// The environment provides contextual information about the current runtime,
  /// such as configuration, resource resolution, or localization services.
  ///
  /// ### Example
  /// ```dart
  /// final env = context.getEnvironment();
  /// final locale = env.getLocale();
  /// ```
  Environment getEnvironment();
}