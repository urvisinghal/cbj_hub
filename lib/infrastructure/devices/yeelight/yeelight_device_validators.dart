import 'package:cbj_hub/domain/generic_devices/abstract_device/core_failures.dart';
import 'package:dartz/dartz.dart';

Either<CoreFailure<String>, String> validateYeelightIdNotEmpty(String input) {
  return right(input);
}

Either<CoreFailure<String>, String> validateYeelightPortNotEmpty(String input) {
  return right(input);
}
