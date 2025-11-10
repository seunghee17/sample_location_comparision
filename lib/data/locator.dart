import 'package:get_it/get_it.dart';
import 'package:sample_location_comparision/data/repositoryimpl/location_repositoryimpl.dart';
import 'package:sample_location_comparision/data/repositoryimpl/motion_repositoryimpl.dart';

import '../domain/repository/location_repository.dart';
import '../domain/repository/motion_repository.dart';

final locator = GetIt.instance;

void setupLocator() {
  locator.registerLazySingleton<MotionRepository>(() => MotionRepositoryImpl());
  locator.registerLazySingleton<LocationRepository>(() => LocationRepositoryImpl(
    motionRepository: locator<MotionRepository>(),
  ));
}