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
import 'package:jetleaf_logging/logging.dart';
import 'package:meta/meta.dart';

import 'annotations.dart';
import 'base.dart';
import 'base_impl.dart';

/// Represents a mapping between an annotation and its resolved constraint data.
///
/// The key is the **annotation** instance applied to a target element (e.g., a field or method),
/// and the value contains additional metadata or a resolved constraint definition
/// derived from that annotation.
typedef _AnnotatedConstraint = MapEntry<Annotation, dynamic>;

/// Represents a resolved validation relationship between a `WhenValidating` annotation
/// and its underlying annotated constraint metadata.
///
/// The key is the **constraint annotation** (a subclass of `WhenValidating`) being validated,
/// while the value holds the associated annotation–constraint pair
/// that provides additional configuration or validation context.
typedef _ConstraintMatch = MapEntry<WhenValidating, _AnnotatedConstraint>;

/// Represents a mapping between a runtime [Annotation] instance and
/// its associated [ConstraintValidator].
///
/// The key is the **annotation** encountered during reflective scanning,
/// and the value is the validator responsible for enforcing its logic.
///
/// Used as an intermediate representation while resolving validators
/// for annotated elements.
typedef _WhenValidatingAnnotated = MapEntry<Annotation, ConstraintValidator>;

/// Represents a composite pair linking a `@WhenValidating` annotation
/// to its resolved annotation–validator association.
///
/// The key is the **`@WhenValidating`** annotation that defines the
/// validation condition or scope.
///
/// The value is a [_WhenValidatingAnnotated] pair that connects an
/// actual annotation instance with its [ConstraintValidator].
///
/// Used by JetLeaf’s validation resolution pipeline to build a
/// structured mapping between conditional validation rules and
/// their executable validators.
typedef _AnnotatedConstraintValidator = MapEntry<WhenValidating, _WhenValidatingAnnotated>;

/// {@template jetleaf_abstract_executable_validator}
/// A **base implementation** of the [ExecutableValidator] interface that provides
/// the foundational logic for executing and orchestrating **annotation-driven**
/// validation in the JetLeaf validation framework.
///
/// This abstract class discovers and executes applicable
/// [ConstraintValidator]s against annotated parameters, return values, and
/// sources within executable contexts such as methods, constructors, or fields.
///
/// ### Core Responsibilities
/// - **Constraint Discovery:** Traverses annotation metadata recursively to
///   locate [Constraint]-annotated elements and their corresponding validators.
/// - **Validator Resolution:** Maps each [WhenValidating] annotation to one or
///   more applicable [ConstraintValidator] instances.
/// - **Execution Orchestration:** Invokes validators in the context of an
///   active [ValidationContext], collecting [ConstraintViolation] results.
/// - **Group-Based Filtering:** Ensures that only validators within the
///   currently active [ValidationGroup] set are applied.
///
/// ### Validation Flow
/// 1. Extract annotated parameters or return values from a given [Method].
/// 2. Resolve all constraints via [findAllConstraints].
/// 3. Construct a [SimpleValidationContext] bound to the current [Environment].
/// 4. Iterate through each discovered [ConstraintValidator].
/// 5. Apply validators conditionally using `shouldValidate` to check group membership.
/// 6. Collect and aggregate violations into a [SimpleValidationReport].
///
/// ### Timezone and Environment Integration
/// Each execution context is bound to an [Environment] instance, allowing
/// constraint validators (such as temporal or configuration-based validators)
/// to operate consistently across distributed systems.  
/// The environment is accessed through [getEnvironment], which must be
/// implemented by subclasses.
///
/// ### Example
/// ```dart
/// final validator = MyExecutableValidator();
/// final report = validator.validateParameters(
///   myService,
///   myMethod,
///   MethodArguments(positional: [userInput])
/// );
///
/// if (report.hasViolations) {
///   for (final violation in report.getViolations()) {
///     print('${violation.propertyPath}: ${violation.message}');
///   }
/// }
/// ```
///
/// ### Key Methods
/// #### 🔹 [getConstraintValidators]
/// Resolves all validators attached to a given [Source], expanding
/// multi-validator constraints into individual pairs of
/// `MapEntry<WhenValidating, ConstraintValidator>`.
///
/// #### 🔹 [findAllConstraints]
/// Recursively inspects annotations on a [Source] to identify all constraints
/// and their associated metadata. Handles nested annotations and reflection
/// safely (ignoring inaccessible or malformed metadata).
///
/// #### 🔹 [validateParameters]
/// Evaluates all constraints on a method’s parameters. Collects violations
/// for any parameters failing their assigned constraints.
///
/// #### 🔹 [validateReturnValue]
/// Performs the same validation pipeline on the method’s return value.
///
/// #### 🔹 [isInGroup]
/// Utility for checking if a constraint belongs to an active validation group.
///
/// #### 🔹 [hasConstraint]
/// Quickly determines if a given source element (class, field, or parameter)
/// contains one or more validation annotations (`@WhenValidating`, `@Valid`,
/// `@Validated`).
///
/// ### Group Semantics
/// JetLeaf supports **validation groups** for scoped or phased validation.
/// The method `shouldValidate` determines whether an annotation’s defined
/// groups intersect with the active validation set.  
/// This enables layered validation strategies (e.g., `@BasicChecks` vs
/// `@AdvancedChecks`).
///
/// ### Logging and Diagnostics
/// Uses [LogFactory] and [Log] for structured trace-level diagnostics.
/// When trace logging is enabled, constraint discovery events and inclusion
/// logic are logged for observability.
///
/// ### Example Violation
/// ```text
/// Property: username
/// Value: ""
/// Constraint: @NotBlank
/// Message: "Username cannot be empty"
/// ```
///
/// ### See Also
/// - [ExecutableValidator]
/// - [ConstraintValidator]
/// - [ValidationContext]
/// - [ConstraintViolation]
/// - [Environment]
/// - [SimpleValidationReport]
/// - [WhenValidating]
/// - [Constraint]
/// - [Validated]
/// - [Valid]
/// {@endtemplate}
abstract class AbstractExecutableValidator implements ExecutableValidator, Validator {
  /// A logger instance for emitting **trace**, **debug**, and **diagnostic** messages
  /// related to validation processing within the [AbstractExecutableValidator].
  ///
  /// This logger records key lifecycle events such as:
  /// - Constraint discovery (`findAllConstraints`)
  /// - Validator resolution (`getConstraintValidators`)
  /// - Parameter and return value evaluation
  ///
  /// Logging behavior is controlled through the JetLeaf [LogFactory] and the
  /// active logging configuration defined in the application’s [Environment].
  ///
  /// When trace-level logging is enabled, each validated [Source] is logged
  /// with its name and constraint inclusion decisions, aiding introspection
  /// and debugging of validator selection.
  ///
  /// ### Example Log Output
  /// ```text
  /// TRACE jetleaf.validation.AbstractExecutableValidator - 
  /// Evaluating constraint inclusion for source: User.email
  /// ```
  final Log _logger = LogFactory.getLog(AbstractExecutableValidator);

  /// Discovers and resolves all **active constraint validators** defined on the
  /// given [Source] (such as a method parameter, return value, or field).
  ///
  /// This method first locates all matching constraints through
  /// [findAllConstraints], then expands each constraint’s validator list into
  /// discrete [_AnnotatedConstraintValidator] pairs of
  /// `MapEntry<WhenValidating, ConstraintValidator>`.
  ///
  /// ### Trace Logging
  /// When trace logging is enabled via [_logger], a diagnostic message is
  /// emitted indicating the source being evaluated for constraint inclusion.
  ///
  /// ### Example
  /// ```dart
  /// final validators = getConstraintValidators(methodParam);
  /// for (final pair in validators) {
  ///   final annotation = pair.key;
  ///   final validator = pair.value;
  ///   print('Validating using ${validator.runtimeType}');
  /// }
  /// ```
  ///
  /// ### Returns
  /// A list of [_AnnotatedConstraintValidator] pairs, each representing a
  /// distinct constraint-validator relationship applicable to the [source].
  ///
  /// ### See Also
  /// - [findAllConstraints]
  /// - [ConstraintValidator]
  /// - [WhenValidating]
  /// - [Source]
  List<_AnnotatedConstraintValidator> getConstraintValidators(Source source) {
    if (_logger.getIsTraceEnabled()) {
      _logger.trace('Evaluating constraint inclusion for source: ${source.getName()}');
    }

    final result = <_AnnotatedConstraintValidator>[];
    final matches = findAllConstraints(source);
    
    if (matches.isNotEmpty) {
      for (final match in matches) {
        final whenValidating = match.key;
        final value = match.value;
        final annotation = value.key;
        final validators = value.value;

        if (validators is List) {
          for (final item in validators) {
            if (item is ConstraintValidator) {
              result.add(MapEntry(whenValidating, MapEntry(annotation, item)));
            }
          }
        }
      }
    }

    return result;
  }

  /// Finds all constraints associated with a given [source].
  ///
  /// This method inspects the annotations on the [source] recursively,
  /// collecting all annotations that are assignable to [Constraint]. For
  /// annotations that themselves extend [WhenValidating], it processes
  /// their nested annotations recursively.
  ///
  /// Each match is returned as a [_ConstraintMatch] (`MapEntry<Annotation, dynamic>`),
  /// where the key is the **original annotation** and the value is the
  /// associated validators (from `Constraint.FIELD_KEY`).
  ///
  /// Reflection errors are silently ignored during traversal.
  ///
  /// Example:
  /// ```dart
  /// final constraints = findAllConstraints(source);
  /// for (final match in constraints) {
  ///   final annotation = match.key;
  ///   final validators = match.value;
  /// }
  /// ```
  List<_ConstraintMatch> findAllConstraints(Source source) {
    final matches = <_ConstraintMatch>[];
    final constraint = Class<Constraint>(null, PackageNames.VALIDATION);
    final whenValidating = Class<WhenValidating>(null, PackageNames.VALIDATION);

    void processAnnotation(Annotation ann) {
      final annClass = ann.getDeclaringClass();

      // Go through all annotations *on the annotation class*
      for (final meta in annClass.getAllAnnotations()) {
        try {
          final metaClass = meta.getDeclaringClass();

          // If the annotation on the annotation class is a Constraint, extract it
          if (constraint.isAssignableFrom(metaClass)) {
            final whenValidatingInstance = ann.getInstance();
            final instance = meta.getInstance();

            if (whenValidatingInstance is WhenValidating && instance is Constraint) {
              matches.add(MapEntry(whenValidatingInstance, MapEntry(meta, instance.validators)));
            }
          }

          // If the annotation class itself is annotated with @WhenValidating, recurse
          if (whenValidating.isAssignableFrom(metaClass)) {
            processAnnotation(meta);
          }
        } catch (e) {
          // ignore reflection failures
        }
      }
    }

    // Start with all annotations directly on the target source (method param, field, etc.)
    for (final ann in source.getAllDirectAnnotations()) {
      try {
        final annClass = ann.getDeclaringClass();

        // If it's a WhenValidating annotation (like @Email, @InFuture, etc.)
        if (whenValidating.isAssignableFrom(annClass)) {
          processAnnotation(ann);
        }

        // If the annotation itself is @Constraint directly
        if (constraint.isAssignableFrom(annClass)) {
          final whenValidatingInstance = ann.getInstance();
          final keyValue = ann.getFieldValue(Constraint.FIELD_KEY);

          if (whenValidatingInstance is WhenValidating) {
            matches.add(MapEntry(whenValidatingInstance, MapEntry(ann, keyValue)));
          }
        }
      } catch (_) {}
    }

    return matches;
  }

  /// Determines whether the provided set of [constraintGroups] intersects
  /// with the currently **active validation groups**.
  ///
  /// This method is used internally to filter out constraints that should not
  /// participate in the current validation phase or execution context.
  ///
  /// ### Returns
  /// - `true` if at least one group from [constraintGroups] matches a group in
  ///   [activeGroups].
  /// - `false` otherwise.
  ///
  /// ### Example
  /// ```dart
  /// final isActive = isInGroup({BasicChecks.classRef}, {BasicChecks.classRef, AdvancedChecks.classRef});
  /// // ✅ Returns true
  /// ```
  ///
  /// ### See Also
  /// - [WhenValidating.groups]
  /// - [DefaultGroup]
  bool isInGroup(Set<Class> constraintGroups, Set<Class> activeGroups) => constraintGroups.intersection(activeGroups).isNotEmpty;
  
  /// Checks whether the given [source] (e.g., class, field, or method parameter)
  /// is annotated with one or more **validation-related annotations**.
  ///
  /// A source is considered to have constraints if it directly or indirectly
  /// contains:
  /// - A [WhenValidating]-based annotation
  /// - A [Valid] marker annotation
  /// - A [Validated] group-level annotation
  ///
  /// When the source is a [Class], this method recursively checks all fields
  /// for such annotations.
  ///
  /// ### Example
  /// ```dart
  /// final hasValidation = hasConstraint(userField);
  /// if (hasValidation) {
  ///   print("Field '${userField.getName()}' requires validation");
  /// }
  /// ```
  ///
  /// ### Returns
  /// `true` if any matching validation annotations are found, `false` otherwise.
  ///
  /// ### See Also
  /// - [WhenValidating]
  /// - [Valid]
  /// - [Validated]
  bool hasConstraint(Source source) {
    if (source is Class) {
      return source.getFields().any((field) => field.getAllDirectAnnotations().any((ann) {
        return ann.matches<WhenValidating>() || ann.matches<Valid>() || ann.matches<Validated>();
      }));
    }

    return source.getAllDirectAnnotations().any((ann) {
      return ann.matches<WhenValidating>() || ann.matches<Valid>() || ann.matches<Validated>();
    });
  }

  /// Checks whether the given [Source] is annotated with `@Valid`.
  ///
  /// This method inspects all direct annotations on the [source]
  /// and returns `true` if any of them match the [`Valid`] annotation.
  ///
  /// Typically used to determine whether a field, parameter, or
  /// method should trigger cascaded validation.
  ///
  /// Example:
  /// ```dart
  /// if (hasValidAnnotation(field)) {
  ///   // perform cascaded validation on nested object
  /// }
  /// ```
  bool hasValidAnnotation(Source source) => source.getAllDirectAnnotations().any((a) => a.matches<Valid>());

  /// Checks whether the given [Source] is annotated with `@Validated`.
  ///
  /// Returns `true` if any direct annotation on the [source]
  /// matches the [`Validated`] meta-annotation, which is typically
  /// used to indicate that a class, method, or parameter participates
  /// in a validation group or scoped validation context.
  ///
  /// Example:
  /// ```dart
  /// if (hasValidatedAnnotation(method)) {
  ///   // perform grouped validation for this method
  /// }
  /// ```
  bool hasValidatedAnnotation(Source source) => source.getAllDirectAnnotations().any((a) => a.matches<Validated>());

  @override
  ValidationReport validateParameters(Object target, Method method, [ExecutableArgument? arguments, Set<Class>? groups]) {
    final violations = <ConstraintViolation>{};
    final context = createContext();
    final argument = arguments ?? ExecutableArgument.none();
    final paramsToValidate = method.getParameters().where(hasConstraint).toList();

    for (final param in paramsToValidate) {
      if (_canBeValidated(param, method)) {
        final activeGroups = resolveActiveGroups(param, method, groups);
        final value = param.isNamed()
            ? argument.getNamedArguments()[param.getName()]
            : argument.getPositionalArguments().elementAtOrNull(param.getIndex());
        
        if (hasConstraint(param.getReturnClass()) && hasValidatedAnnotation(param) && value != null) {
          final report = validate(value, param.getReturnClass(), activeGroups);
          violations.addAll(report.getViolations());
        }

        violations.addAll(_validateConstraints(param, value, context, activeGroups));
      }
    }

    return SimpleValidationReport(violations);
  }

  /// Determines whether the provided [Source] can participate in validation.
  ///
  /// This method checks if the [primary] source (such as a method, field,
  /// or parameter) is annotated with `@Validated`. If not, it optionally
  /// inspects the [secondary] source (e.g., its return type or enclosing class)
  /// for the same annotation.
  ///
  /// Returns:
  /// - `true` if either [primary] or [secondary] is annotated with `@Validated`.
  /// - `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// if (_canBeValidated(method, method.getReturnClass())) {
  ///   // Proceed with return value validation
  /// }
  /// ```
  bool _canBeValidated(Source primary, [Source? secondary]) =>
    hasValidatedAnnotation(primary) || (secondary != null && hasValidatedAnnotation(secondary));

  /// Resolves the effective validation groups for a given [Source].
  ///
  /// This method determines which validation groups should be active based on
  /// three possible sources of information:
  ///
  /// 1. If [override] is provided, it takes precedence.
  /// 2. If the [primary] source has a `@Valid` annotation, its groups are used.
  /// 3. Otherwise, if the [fallback] source is annotated with `@Validated`,
  ///    its groups are resolved.
  /// 4. If none of the above apply, defaults to the groups declared on [primary].
  ///
  /// Returns:
  /// - A [Set] of active [Class] instances representing the groups to validate.
  ///
  /// Example:
  /// ```dart
  /// final groups = _resolveActiveGroups(parameter, method, externalGroups);
  /// ```
  @protected
  Set<Class> resolveActiveGroups(Source primary, [Source? fallback, Set<Class>? override]) {
    if (override != null) return getActiveGroups(override);

    if (hasValidAnnotation(primary)) return getValidationGroups(primary);
    if (fallback != null && hasValidatedAnnotation(fallback)) return getValidationGroups(fallback);

    return getValidationGroups(primary);
  }

  /// Executes all constraint validators associated with the given [Source].
  ///
  /// This method retrieves registered constraint validators for the [source],
  /// evaluates them in order, and collects any resulting [ConstraintViolation]s.
  ///
  /// Each validator is checked against the active validation groups; only those
  /// whose groups intersect with [activeGroups] will be executed.
  ///
  /// Returns:
  /// - A [Set] of [ConstraintViolation]s produced by failing validators.
  ///
  /// Example:
  /// ```dart
  /// final violations = _validateConstraints(field, value, context, groups);
  /// ```
  Set<ConstraintViolation> _validateConstraints(Source source, Object? value, ValidationContext context, Set<Class> activeGroups) {
    final violations = <ConstraintViolation>{};
    final validators = getConstraintValidators(source);

    for (final validator in validators) {
      final annotation = validator.key;
      final entry = validator.value;
      final constraintValidator = entry.value;

      if (!shouldValidate(annotation, getActiveGroups(activeGroups))) continue;

      if (!constraintValidator.isValid(value, annotation, context)) {
        violations.add(buildViolation(source, annotation, entry, value, activeGroups));
      }
    }

    return violations;
  }

  /// Constructs a detailed [ConstraintViolation] instance for a failed constraint.
  ///
  /// This method encapsulates the creation of a standardized violation object,
  /// ensuring consistent reporting across all validation contexts.
  ///
  /// It includes the property path, invalid value, constraint metadata, resolved
  /// message (including placeholder interpolation), active groups, and payloads.
  ///
  /// Returns:
  /// - A [DetailedConstraintViolation] representing the validation failure.
  ///
  /// Example:
  /// ```dart
  /// final violation = _buildViolation(param, annotation, entry, value, groups);
  /// ```
  @protected
  ConstraintViolation buildViolation(Source source, WhenValidating annotation, MapEntry<Annotation, dynamic> entry, Object? value, Set<Class> activeGroups) {
    return DetailedConstraintViolation(
      propertyPath: source.getName(),
      invalidValue: value,
      source: source,
      message: annotation.getMessage(entry.key.getAllFieldValues().map((k, v) => MapEntry(k, v.toString()))),
      constraintAnnotation: annotation,
      groups: getActiveGroups(activeGroups),
      payloads: annotation.payloads.toSet(),
    );
  }

  /// Resolves the active validation groups declared on the given [Source].
  ///
  /// This method inspects the [source] for a direct [`@Validated`] annotation
  /// and extracts its associated `group` types. Each declared type is converted
  /// into a reflective [Class] instance using [`toClass()`].
  ///
  /// If no `@Validated` annotation is present, an empty set is returned.
  ///
  /// Example:
  /// ```dart
  /// final groups = getGroups(method);
  /// // e.g., {AdminGroup, DefaultGroup}
  /// ```
  ///
  /// Returns:
  /// - A [Set] of [Class] objects representing the validation groups
  ///   explicitly declared on the annotated element.
  Set<Class> getValidationGroups(Source source) {
    final groups = <Class>{};
    final annotation = source.getDirectAnnotation<Validated>();
    final group = annotation?.group.map((type) => type.toClass()).toList();

    if (group != null) {
      groups.addAll(group);
    }

    if (groups.isEmpty) {
      groups.add(DefaultGroup.getClass());
    }

    return groups;
  }

  /// Resolves the active validation groups for a constraint evaluation.
  ///
  /// If [groups] is `null` or empty, this method defaults to returning
  /// the [DefaultGroup] to ensure that at least one validation group
  /// is always active.
  ///
  /// Example:
  /// ```dart
  /// final activeGroups = getActiveGroup(userDefinedGroups);
  /// // Returns userDefinedGroups if provided, otherwise {DefaultGroup.getClass()}
  /// ```
  ///
  /// Returns:
  /// - The provided [groups] set, if not `null`.
  /// - Otherwise, a singleton set containing [DefaultGroup.getClass()].
  Set<Class> getActiveGroups(Set<Class>? groups) => groups ?? {DefaultGroup.getClass()};

  /// Creates a new [SimpleValidationContext] bound to the current
  /// [Environment] instance.
  ///
  /// This method serves as a factory for producing the contextual
  /// environment in which all constraint evaluations occur.
  ///  
  /// Each [ConstraintValidator] receives this context for accessing
  /// configuration properties, timezone data, and environment-bound state.
  ///
  /// ### Example
  /// ```dart
  /// final context = createContext();
  /// final env = context.getEnvironment();
  /// print(env.getProperty("application.timezone"));
  /// ```
  ///
  /// ### Returns
  /// A fresh [SimpleValidationContext] configured with [getEnvironment].
  ///
  /// ### See Also
  /// - [SimpleValidationContext]
  /// - [Environment]
  /// - [ValidationContext]
  SimpleValidationContext createContext() => SimpleValidationContext(getEnvironment());

  /// Determines whether a given [WhenValidating] annotation should participate
  /// in the current validation run based on the active validation groups.
  ///
  /// This method converts the annotation’s declared `groups` into a
  /// [Set<Class>] and checks whether any of those groups intersect with the
  /// provided [activeGroups].
  ///
  /// ### Example
  /// ```dart
  /// final annotation = InFuture(groups: [AdvancedChecks]);
  /// final shouldRun = shouldValidate(annotation, {AdvancedChecks.toClass()});
  /// // ✅ Returns true — group intersection found
  /// ```
  ///
  /// ### Returns
  /// `true` if the annotation belongs to an active validation group;
  /// otherwise, `false`.
  ///
  /// ### See Also
  /// - [WhenValidating.groups]
  /// - [isInGroup]
  /// - [DefaultGroup]
  bool shouldValidate(WhenValidating annotation, Set<Class> activeGroups) {
    final groups = annotation.groups.map((g) => g.toClass()).toSet();
    return groups.intersection(activeGroups).isNotEmpty;
  }

  @override
  ValidationReport validateReturnValue(Object target, Method method, Object? returnValue, [Set<Class>? groups]) {
    final violations = <ConstraintViolation>{};

    if (_canBeValidated(method, method.getReturnClass())) {
      final context = createContext();
      final activeGroups = resolveActiveGroups(method, method.getReturnClass(), groups);
      violations.addAll(_validateConstraints(method, returnValue, context, activeGroups));
    }

    return SimpleValidationReport(violations);
  }

  /// Provides access to the currently active JetLeaf [Environment].
  ///
  /// Concrete subclasses of [AbstractExecutableValidator] must implement this
  /// method to supply the operational environment used during validation.
  ///
  /// The environment is typically responsible for:
  /// - Providing timezone and locale configuration
  /// - Managing system-wide validation and logging settings
  /// - Supplying contextual properties to constraint validators
  ///
  /// ### Example
  /// ```dart
  /// @override
  /// Environment getEnvironment() => AppEnvironment.current;
  /// ```
  ///
  /// ### See Also
  /// - [Environment]
  /// - [SimpleValidationContext]
  /// - [ConstraintValidator]
  @protected
  Environment getEnvironment();
}