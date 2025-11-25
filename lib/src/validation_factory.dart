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

import 'dart:async';

import 'package:jetleaf_core/annotation.dart';
import 'package:jetleaf_core/context.dart';
import 'package:jetleaf_core/core.dart';
import 'package:jetleaf_core/intercept.dart';
import 'package:jetleaf_env/env.dart';
import 'package:jetleaf_lang/lang.dart';

import 'abstract_executable_validator.dart';
import 'base.dart';
import 'base_impl.dart';
import 'exceptions.dart';

/// {@template jetleaf_validation_factory}
/// A **centralized, interceptor-aware validation engine** responsible for
/// performing runtime constraint validation across objects, method parameters,
/// and return values within a JetLeaf application.
///
/// The [ValidationFactory] integrates seamlessly with the JetLeaf
/// [ApplicationContext], enabling **environment-aware**, **group-based**, and
/// **recursive validation** of annotated entities.
///
/// ### Core Responsibilities
/// - Performs object-level and property-level validation using registered
///   [ConstraintValidator] implementations.
/// - Supports method interception for automatic validation of:
///   - **Method parameters** before invocation.
///   - **Method return values** after successful execution.
/// - Resolves constraint groups, nested validations (`@Valid`), and
///   environment-specific behaviors (e.g., timezone or locale-based logic).
///
/// ### Integration with ApplicationContext
/// The validator is initialized as an [ApplicationContextAware] component,
/// allowing it to access:
/// - The active [Environment] configuration.
/// - Application-level lifecycle and dependency management.
/// - Global event publication mechanisms.
///
/// ### Validation Workflow
/// 1. **Object or property inspection** — Gathers annotations and determines
///    applicable [ConstraintValidator] instances via reflection.
/// 2. **Recursive validation** — Invokes nested validation when encountering
///    `@Valid` or similar annotations.
/// 3. **Constraint evaluation** — Delegates each constraint to its validator.
/// 4. **Report aggregation** — Collects violations into a [ValidationReport].
/// 5. **Exception escalation** — Throws a [ConstraintViolationException] when
///    invoked through AOP interceptors and violations are detected.
///
/// ### Interceptor Behavior
/// The [ValidationFactory] implements multiple interceptor interfaces:
///
/// - [MethodBeforeInterceptor] → validates **parameters** before invocation.
/// - [AfterReturningInterceptor] → validates **return values** after execution.
/// - [MethodInterceptor] → enables conditional interception via [canIntercept].
///
/// This ensures declarative validation without requiring explicit method calls.
///
/// ### Example
/// ```dart
/// @Service()
/// class BookingService {
///   @Validated()
///   Booking create(@NotNull() BookingRequest request) {
///     // Automatically validated before this line
///     return Booking(...);
///   }
/// }
///
/// // Intercepted automatically by ValidationFactory
/// final booking = bookingService.create(null);
/// // → throws ConstraintViolationException
/// ```
///
/// ### Example Violation Output
/// ```text
/// Validation failed with the following violations:
///  • Property: "request.date"
///    Message : "must be in the future"
///    Invalid : 2023-01-01T00:00:00Z
///    Source  : FieldMirrorImpl
/// ```
///
/// ### Design Notes
/// - Implements both [Validator] and [ExecutableValidator] for unified validation.
/// - Interceptor methods (`beforeInvocation`, `afterReturning`) enforce
///   validation boundaries automatically.
/// - Uses [ConstraintViolationException] to standardize validation errors.
///
/// ### See Also
/// - [Validator]
/// - [ExecutableValidator]
/// - [ConstraintViolationException]
/// - [ApplicationContext]
/// - [Environment]
/// - [MethodInterceptor]
/// {@endtemplate}
@Order(2)
final class ValidationFactory extends AbstractExecutableValidator implements Validator, MethodInterceptor, MethodBeforeInterceptor, AfterReturningInterceptor, ApplicationContextAware {
  /// The **active JetLeaf [ApplicationContext]** associated with this registrar.
  ///
  /// Provides access to:
  /// - The application’s environment configuration (e.g., profiles, properties).
  /// - Event publication and subscription mechanisms.
  /// - The global lifecycle scope for cache components.
  ///
  /// Used primarily for cleanup coordination and contextual property lookups
  /// (such as determining cache error handling style).
  late ApplicationContext _applicationContext;

  /// {@macro jetleaf_validation_factory}
  ValidationFactory();

  @override
  void setApplicationContext(ApplicationContext applicationContext) {
    _applicationContext = applicationContext;
  }

  @override
  Environment getEnvironment() => _applicationContext.getEnvironment();

  @override
  List<Object?> equalizedProperties() => [ValidationFactory];

  @override
  ExecutableValidator forExecutables() => this;

  @override
  ValidationReport validate(Object target, Class? targetClass, [Set<Class>? groups]) {
    final violations = <ConstraintViolation>{};
    final classInfo = targetClass ?? target.getClass();
    final context = createContext();

    for (final field in classInfo.getFields()) {
      final value = field.getValue(target);
      final activeGroups = resolveActiveGroups(field, field.getReturnClass(), groups);

      if (hasValidAnnotation(field) && value != null) {
        final report = validate(value, field.getReturnClass(), activeGroups);
        violations.addAll(report.getViolations());
      }

      final validators = getConstraintValidators(field);
      
      if (validators.isEmpty) {
        continue;
      }

      for (final validator in validators) {
        final annotation = validator.key;
        final v = validator.value;
        final constraintValidator = v.value;

        // 🟡 Skip if not part of active group(s)
        if (!shouldValidate(annotation, getActiveGroups(activeGroups))) continue;

        if (!constraintValidator.isValid(value, annotation, context)) {
          violations.add(buildViolation(field, annotation, v, value, activeGroups));
        }
      }
    }

    return SimpleValidationReport(violations);
  }

  @override
  ValidationReport validateProperty(Object target, Class? targetClass, String propertyName, [Set<Class>? groups]) {
    final violations = <ConstraintViolation>{};
    final classInfo = targetClass ?? target.getClass();
    final context = createContext();
    final field = classInfo.getFields().find((field) => field.getName().equals(propertyName));

    if (field == null) {
      return SimpleValidationReport();
    }

    final value = field.getValue(target);
    final activeGroups = resolveActiveGroups(field, field.getReturnClass(), groups);

    if (hasValidAnnotation(field) && value != null) {
      final report = validate(value, field.getReturnClass(), activeGroups);
      violations.addAll(report.getViolations());
    }

    final validators = getConstraintValidators(field);
    
    if (validators.isEmpty) {
      return SimpleValidationReport();
    }

    for (final validator in validators) {
      final annotation = validator.key;
      final v = validator.value;
      final constraintValidator = v.value;

      // 🟡 Skip if not part of active group(s)
      if (!shouldValidate(annotation, getActiveGroups(groups))) continue;

      if (!constraintValidator.isValid(value, annotation, context)) {
        violations.add(buildViolation(field, annotation, v, value, activeGroups));
      }
    }

    return SimpleValidationReport(violations);
  }

  @override
  bool canIntercept(Method method) {
    if (method.getParameters().any((param) => hasConstraint(param))) {
      return true;
    }

    if (hasConstraint(method.getReturnClass())) {
      return true;
    }

    if (hasConstraint(method)) {
      return true;
    }

    return false;
  }

  @override
  FutureOr<void> beforeInvocation<T>(MethodInvocation<T> invocation) {
    final report = validateParameters(invocation.getTarget(), invocation.getMethod(), invocation.getArgument());

    // If any violations exist, throw immediately
    if (!report.isValid()) {
      throw ConstraintViolationException(report);
    }
  }

  @override
  FutureOr<void> afterReturning<T>(MethodInvocation<T> invocation, Object? returnValue, Class? returnClass) {
    final report = validateReturnValue(invocation.getTarget(), invocation.getMethod(), returnValue);

    // If any violations exist, throw immediately
    if (!report.isValid()) {
      throw ConstraintViolationException(report);
    }
  }
}