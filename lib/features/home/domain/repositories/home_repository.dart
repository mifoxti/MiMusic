import '../entities/home_section.dart';

/// Репозиторий данных главного экрана (domain — только контракт).
abstract interface class HomeRepository {
  Future<HomeSection> getHomeSection();
}
