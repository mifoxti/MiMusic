import '../entities/home_section.dart';
import '../repositories/home_repository.dart';

/// Сценарий получения данных для главного экрана.
class GetHomeSectionUseCase {
  GetHomeSectionUseCase(this._repository);

  final HomeRepository _repository;

  Future<HomeSection> call() => _repository.getHomeSection();
}
