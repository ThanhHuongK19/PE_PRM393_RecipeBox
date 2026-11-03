import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Firebase client SDK handles shared with data services through dependency injection.
class FirebaseServices {
  FirebaseServices.forApp(FirebaseApp app)
    : auth = FirebaseAuth.instanceFor(app: app),
      firestore = FirebaseFirestore.instanceFor(app: app);

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
}
