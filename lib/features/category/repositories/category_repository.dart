import '../models/service_category.dart';

abstract class CategoryRepository {
  Future<List<ServiceCategory>> fetchActiveCategories();
}
