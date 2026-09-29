import '../models/service_category.dart';
import 'category_repository.dart';

class MockCategoryRepository implements CategoryRepository {
  @override
  Future<List<ServiceCategory>> fetchActiveCategories() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    return const [
      ServiceCategory(
        id: 'general',
        name: 'General',
        requiresVerification: false,
      ),
      ServiceCategory(
        id: 'teacher',
        name: 'Teacher',
        requiresVerification: true,
      ),
      ServiceCategory(
        id: 'doctor',
        name: 'Doctor',
        requiresVerification: true,
      ),
      ServiceCategory(
        id: 'model',
        name: 'Model',
        requiresVerification: false,
      ),
      ServiceCategory(
        id: 'singer',
        name: 'Singer',
        requiresVerification: false,
      ),
      ServiceCategory(
        id: 'storyteller',
        name: 'Storyteller',
        requiresVerification: false,
      ),
    ];
  }
}
