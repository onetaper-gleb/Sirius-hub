import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:client/domain/model/model.dart';

class UserFirestoreDataSource {
  final FirebaseFirestore _firestore;

  UserFirestoreDataSource({required FirebaseFirestore firestore})
    : _firestore = firestore;

  Future<void> saveUser(UserModel user) async {
    await _firestore.collection('users').doc(user.id).set(user.toFirestore());
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists && doc.data() != null) {
        return UserModel.fromFirestore(doc.id, doc.data()!);
      }
    } catch (e) {
    }
    return null;
  }
}
