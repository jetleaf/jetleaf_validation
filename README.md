# ✅ JetLeaf Validation — Data Validation & Constraints

[![pub package](https://img.shields.io/badge/version-1.0.0-blue)](https://pub.dev/packages/jetleaf_validation)
[![License](https://img.shields.io/badge/license-JetLeaf-green)](#license)
[![Dart SDK](https://img.shields.io/badge/sdk-%3E%3D3.9.0-blue)](https://dart.dev)

Comprehensive data validation framework with declarative constraints and custom validators for JetLeaf applications.

## 📋 Overview

`jetleaf_validation` provides robust validation capabilities:

- **Declarative Constraints** — Annotations for input validation
- **Built-in Validators** — Common validation rules
- **Custom Validators** — Domain-specific validation logic
- **Validation Groups** — Selective constraint validation
- **Nested Validation** — Validate object hierarchies
- **Collection Validation** — Validate lists and maps
- **Error Messages** — Customizable validation messages
- **Pod Integration** — Auto-validate pod properties

## 🚀 Quick Start

### Installation

```yaml
dependencies:
  jetleaf_validation: ^1.0.0
```

### Basic Validation

```dart
import 'package:jetleaf_validation/validation.dart';

class User {
  @NotNull(message: 'Username cannot be null')
  @Size(min: 3, max: 20, message: 'Username must be 3-20 characters')
  late String username;

  @Email(message: 'Invalid email address')
  late String email;

  @Range(min: 18, max: 120, message: 'Age must be 18-120')
  late int age;
}

void main() {
  final validator = Validator();
  
  final user = User();
  user.username = 'ab';  // Too short
  user.email = 'invalid-email';
  user.age = 15;  // Too young

  final violations = validator.validate(user);
  
  for (final violation in violations) {
    print('${violation.propertyPath}: ${violation.message}');
  }
  // Output:
  // username: Username must be 3-20 characters
  // email: Invalid email address
  // age: Age must be 18-120
}
```

## 📚 Key Features

### 1. Built-in Constraints

**Common validation annotations**:

```dart
class Product {
  @NotNull()
  @NotEmpty(message: 'Product name required')
  String? name;

  @Size(min: 10, max: 500)
  String? description;

  @Min(value: 0)
  @Max(value: 100)
  int discount = 0;

  @Positive(message: 'Price must be positive')
  double? price;

  @Email()
  String? contactEmail;

  @Pattern(regex: r'^[A-Z0-9]{10}$', message: 'Invalid product code')
  String? productCode;

  @NotBlank(message: 'SKU cannot be blank')
  String? sku;
}

final validator = Validator();
final violations = validator.validate(product);
```

### 2. Custom Validators

**Domain-specific validation logic**:

```dart
import 'package:jetleaf_validation/validation.dart';

@Target({TargetKind.field})
class ValidPhoneNumber extends ConstraintValidator<PhoneNumber, String> {
  @override
  bool isValid(String? value, ConstraintValidatorContext context) {
    if (value == null || value.isEmpty) {
      return true;  // @NotNull handles nulls
    }

    final cleaned = value.replaceAll(RegExp('[^0-9]'), '');
    
    // Valid if it's 10 digits (after removing non-digits)
    if (cleaned.length != 10) {
      context.buildConstraintViolationWithTemplate(
        'Phone number must be 10 digits'
      ).addConstraintViolation();
      return false;
    }
    
    return true;
  }
}

@PhoneNumber()
String userPhone = '(555) 123-4567';
```

### 3. Validation Groups

**Selective constraint validation**:

```dart
class User {
  @NotNull(groups: [ValidationGroup.CREATE])
  @Size(min: 3, max: 20)
  late String username;

  @Email(groups: [ValidationGroup.CREATE, ValidationGroup.UPDATE])
  late String email;

  @NotNull(groups: [ValidationGroup.UPDATE])
  late String id;
}

enum ValidationGroup {
  CREATE,
  UPDATE,
}

// Validate only CREATE constraints
final violations = validator.validate(user, groups: [ValidationGroup.CREATE]);

// Validate only UPDATE constraints
final violations = validator.validate(user, groups: [ValidationGroup.UPDATE]);
```

### 4. Nested Validation

**Validate object hierarchies**:

```dart
class Address {
  @NotNull()
  @Size(min: 3)
  late String street;

  @NotNull()
  late String city;

  @Size(min: 5, max: 10)
  late String zipCode;
}

class Person {
  @NotNull()
  late String name;

  @Valid()  // Validate nested object
  late Address address;

  @Valid()  // Validate all items in collection
  late List<Address> previousAddresses;
}

final violations = validator.validate(person);
// Will recursively validate person, address, and previousAddresses
```

### 5. Collection Validation

**Validate lists and maps**:

```dart
class Team {
  @Size(min: 1, max: 50)
  List<@NotNull @Valid Member> members = [];

  @NotEmpty(message: 'Must have team lead')
  Member? teamLead;

  Map<String, @Valid Position> positions = {};
}

class Member {
  @NotNull()
  late String name;

  @Range(min: 0, max: 100)
  late int experience;
}

class Position {
  @NotNull()
  late String title;

  @Positive()
  late double salary;
}

final violations = validator.validate(team);
```

### 6. Integration with Pods

**Automatic validation in services**:

```dart
@Service()
class UserService {
  final Validator _validator;

  @Autowired
  UserService(this._validator);

  Future<void> createUser(User user) async {
    // Validate before processing
    final violations = _validator.validate(user, groups: [ValidationGroup.CREATE]);
    
    if (violations.isNotEmpty) {
      throw ValidationException(violations);
    }

    // Process user
    await _userRepository.save(user);
  }
}
```

### 7. REST Controller Integration

**Validate request bodies**:

```dart
@RestController('/api/users')
class UserController {
  final UserService _service;
  final Validator _validator;

  @Autowired
  UserController(this._service, this._validator);

  @PostMapping('/')
  Future<HttpResponse> createUser(
    @RequestBody User user,
  ) async {
    // Validate input
    final violations = _validator.validate(user, groups: [ValidationGroup.CREATE]);
    
    if (violations.isNotEmpty) {
      return HttpResponse.badRequest({
        'error': 'Validation failed',
        'violations': violations.map((v) => {
          'field': v.propertyPath,
          'message': v.message,
        }).toList(),
      });
    }

    await _service.createUser(user);
    return HttpResponse.created(user);
  }
}
```

## 📖 Built-in Constraints

| Constraint | Target | Purpose |
|-----------|--------|---------|
| `@NotNull` | Any | Value cannot be null |
| `@NotEmpty` | Collections, String | Value cannot be empty |
| `@NotBlank` | String | String cannot be blank |
| `@Size(min, max)` | Collections, String | Size constraints |
| `@Min(value)` | Number | Minimum value |
| `@Max(value)` | Number | Maximum value |
| `@Range(min, max)` | Number | Range constraints |
| `@Positive` | Number | Must be > 0 |
| `@Negative` | Number | Must be < 0 |
| `@Email` | String | Valid email format |
| `@Pattern(regex)` | String | Regex pattern match |
| `@Valid` | Object | Nested validation |

## 🎯 Common Patterns

### Pattern 1: Form Validation

```dart
class RegistrationForm {
  @NotNull()
  @Size(min: 3, max: 20)
  late String username;

  @NotNull()
  @Email()
  late String email;

  @NotNull()
  @Size(min: 8, message: 'Password must be at least 8 characters')
  late String password;

  @NotNull()
  @AssertTrue(message: 'Must agree to terms')
  late bool agreedToTerms;
}

@RestController('/auth')
class AuthController {
  final Validator _validator;

  @PostMapping('/register')
  Future<HttpResponse> register(@RequestBody RegistrationForm form) async {
    final violations = _validator.validate(form);
    if (violations.isNotEmpty) {
      return HttpResponse.badRequest({
        'errors': violations.map((v) => v.message).toList(),
      });
    }

    // Proceed with registration
    return HttpResponse.ok({'status': 'registered'});
  }
}
```

### Pattern 2: Business Rule Validation

```dart
class Order {
  @NotNull()
  late String customerId;

  @NotEmpty(message: 'Order must have items')
  late List<OrderItem> items;

  @Range(min: 0)
  late double totalAmount;

  @AssertTrue(message: 'Total must match item sum')
  bool isTotalCorrect() {
    final sum = items.fold<double>(
      0,
      (sum, item) => sum + item.price,
    );
    return (sum - totalAmount).abs() < 0.01;
  }
}
```

## ⚠️ Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Validation not running | Validator not called | Explicitly call `validator.validate()` |
| Nested validation skipped | Missing `@Valid` | Add `@Valid` annotation to nested objects |
| Custom validator not used | Not registered | Register with validator factory |
| Message not customized | Default message used | Add `message` parameter to constraint |

## 📋 Best Practices

### ✅ DO

- Define validation constraints close to fields
- Use validation groups for different operations
- Provide meaningful error messages
- Validate early in request processing
- Test validators independently
- Use `@Valid` for nested objects
- Create custom validators for business rules

### ❌ DON'T

- Perform heavy validation in constructors
- Mix validation with business logic
- Ignore validation violations
- Create overly complex validators
- Share validator instances unsafely
- Forget to validate nested collections

## 📦 Dependencies

- **`jetleaf_lang`** — Language utilities
- **`jetleaf_logging`** — Structured logging
- **`jetleaf_pod`** — Pod lifecycle
- **`jetleaf_core`** — Core framework
- **`jetleaf_env`** — Environment configuration

## 📄 License

This package is part of the JetLeaf Framework. See LICENSE in the root directory.

## 🔗 Related Packages

- **`jetleaf_core`** — Framework integration
- **`jetleaf_web`** — HTTP request validation
- **`jetson`** — JSON validation

## 📞 Support

For issues, questions, or contributions, visit:
- [GitHub Issues](https://github.com/jetleaf/jetleaf_validation/issues)
- [Documentation](https://jetleaf.hapnium.com/docs/validation)
- [Community Forum](https://forum.jetleaf.hapnium.com)

---

**Created with ❤️ by [Hapnium](https://hapnium.com)**
