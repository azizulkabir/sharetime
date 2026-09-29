import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/service_category.dart';
import 'category_repository.dart';

class FirebaseCategoryRepository implements CategoryRepository {
  FirebaseCategoryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<ServiceCategory>> fetchActiveCategories() async {
    final snapshot = await _firestore
        .collection('categories')
        .where('isActive', isEqualTo: true)
        .get();

    final categories = snapshot.docs
        .map(
          (doc) => ServiceCategory.fromMap(
            doc.id,
            doc.data(),
          ),
        )
        .where((category) => category.name.trim().isNotEmpty)
        .toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    return categories;
  }
}
