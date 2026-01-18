import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/portfolio_item.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Auth
  Future<String?> signIn(String email, String password) async {
    try { await _auth.signInWithEmailAndPassword(email: email, password: password); return null; }
    on FirebaseAuthException catch (e) { return e.message; }
  }
  
  Future<String?> signUp(String email, String password) async {
    try {
      UserCredential res = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      if(res.user != null) await _db.collection('users').doc(res.user!.uid).set({'email': email});
      return null;
    } on FirebaseAuthException catch (e) { return e.message; }
  }
  
  Future<void> signOut() => _auth.signOut();

  // --- PORTFOLIO LOGIC ---

  Future<void> addToPortfolio(String symbol, String name, double price, double quantity, String type) async {
    if (currentUser == null) return;

    await _db.collection('users').doc(currentUser!.uid).collection('portfolio').add({
      'symbol': symbol,
      'name': name,
      'averagePrice': price,
      'quantity': quantity,
      'type': type, // 'US', 'BIST', 'CRYPTO', 'COMMODITY', 'CURRENCY'
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<PortfolioItem>> getPortfolioStream() {
    if (currentUser == null) return const Stream.empty();

    return _db.collection('users').doc(currentUser!.uid).collection('portfolio').orderBy('addedAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => PortfolioItem.fromFirestore(doc.data(), doc.id)).toList();
    });
  }
}