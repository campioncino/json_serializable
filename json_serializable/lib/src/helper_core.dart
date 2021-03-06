// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:source_gen/source_gen.dart';

import 'json_key_with_conversion.dart';
import 'json_serializable_generator.dart';
import 'type_helper.dart';
import 'type_helper_context.dart';
import 'utils.dart';

abstract class HelperCore {
  final ClassElement element;
  final JsonSerializable annotation;
  final JsonSerializableGenerator generator;

  HelperCore(this.generator, this.element, this.annotation);

  void addMember(String memberContent);

  String get targetClassReference =>
      '${element.name}${genericClassArgumentsImpl(false)}';

  String nameAccess(FieldElement field) => jsonKeyFor(field).name;

  String safeNameAccess(FieldElement field) =>
      escapeDartString(nameAccess(field));

  String get prefix => '_\$${element.name}';

  /// Returns a [String] representing the type arguments that exist on
  /// [element].
  ///
  /// Returns the output of calling [genericClassArguments] with [element].
  String genericClassArgumentsImpl(bool withConstraints) =>
      genericClassArguments(element, withConstraints);

  JsonKeyWithConversion jsonKeyFor(FieldElement field) =>
      JsonKeyWithConversion(field, annotation);

  TypeHelperContext getHelperContext(FieldElement field) =>
      TypeHelperContext(this, field.metadata, jsonKeyFor(field));
}

InvalidGenerationSourceError createInvalidGenerationError(
    String targetMember, FieldElement field, UnsupportedTypeError e) {
  var message = 'Could not generate `$targetMember` code for `${field.name}`';

  var todo = 'Make sure all of the types are serializable.';

  if (e.type.isUndefined) {
    message = '$message because the type is undefined.';
    todo = "Check your imports. If you're trying to generate code for a "
        'Platform-provided type, you may have to specify a custom '
        '`$targetMember` in the associated `@JsonKey` annotation.';
  } else {
    if (field.type != e.type) {
      message = '$message because of type `${e.type}`';
    }

    message = '$message.\n${e.reason}';
  }

  return InvalidGenerationSourceError(message, todo: todo, element: field);
}

/// Returns a [String] representing the type arguments that exist on
/// [element].
///
/// If [withConstraints] is `null` or if [element] has no type arguments, an
/// empty [String] is returned.
///
/// If [withConstraints] is true, any type constraints that exist on [element]
/// are included.
///
/// For example, for class `class Sample<T as num, S>{...}`
///
/// For [withConstraints] = `false`:
///
/// ```
/// "<T, S>"
/// ```
///
/// For [withConstraints] = `true`:
///
/// ```
/// "<T as num, S>"
/// ```
String genericClassArguments(ClassElement element, bool withConstraints) {
  if (withConstraints == null || element.typeParameters.isEmpty) {
    return '';
  }
  var values = element.typeParameters
      .map((t) => withConstraints ? t.toString() : t.name)
      .join(', ');
  return '<$values>';
}

void warnUndefinedElements(Iterable<VariableElement> elements) {
  for (var element in elements.where((fe) => fe.type.isUndefined)) {
    var span = spanForElement(element);
    log.warning('''
This element has an undefined type. It may causes issues when generated code.
${span.start.toolString}
${span.highlight()}''');
  }
}
