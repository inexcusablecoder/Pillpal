import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;

  Future<User?> signUpWithEmail(String email, String password, String name) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user?.updateDisplayName(name);
    await _createUserDoc(cred.user!, name);
    return cred.user;
  }

  Future<User?> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  Future<User?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    final userDoc = await _db.collection('users').doc(cred.user!.uid).get();
    if (!userDoc.exists) {
      await _createUserDoc(cred.user!, cred.user!.displayName ?? 'User');
    }
    return cred.user;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> _createUserDoc(User user, String name) async {
    await _db.collection('users').doc(user.uid).set({
      'displayName': name,
      'email': user.email ?? '',
      'streakCount': 0,
      'adherenceScore': 0,
      'familyMembers': [],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
