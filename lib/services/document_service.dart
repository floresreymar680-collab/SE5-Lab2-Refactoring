// lib/services/document_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firebase_constants.dart';
import '../constants/app_constants.dart';
import '../models/document_model.dart';
import '../services/audit_log_service.dart';
import '../utils/uuid_utils.dart';

class DocumentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuditLogService _auditLog = AuditLogService();

  // ── Add a document link ───────────────────────────────────────────────────
  Future<bool> addDocument({
    required String pwdId,
    required String fileName,
    required String fileLink,
    required String fileType,
    required String description,
    required String uploadedBy,
    required String uploadedByName,
    required String role,
  }) async {
    try {
      final String docId = generateUUID();

      final doc = DocumentModel(
        documentId: docId,
        pwdId: pwdId,
        fileName: fileName.trim(),
        fileLink: fileLink.trim(),
        fileType: fileType,
        description: description.trim(),
        uploadedBy: uploadedBy,
        uploadedByName: uploadedByName,
        uploadedAt: DateTime.now(),
      );

      await _firestore
          .collection(FirebaseConstants.documentsCollection)
          .doc(docId)
          .set(doc.toMap());

      await _auditLog.insertLog(
        userId: uploadedBy,
        userFullName: uploadedByName,
        role: role,
        actionType: AppConstants.actionDocumentLinked,
        affectedTable: FirebaseConstants.documentsCollection,
        affectedRecordId: docId,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Fetch all documents for a PWD ─────────────────────────────────────────
  Future<List<DocumentModel>> fetchDocumentsForPWD(String pwdId) async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseConstants.documentsCollection)
          .where('pwdId', isEqualTo: pwdId)
          .orderBy('uploadedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => DocumentModel.fromDocument(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ── Delete a document record (Admin only) ─────────────────────────────────
  Future<bool> deleteDocument(String documentId) async {
    try {
      await _firestore
          .collection(FirebaseConstants.documentsCollection)
          .doc(documentId)
          .delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Validate URL format ───────────────────────────────────────────────────
  String? validateLink(String url) {
    if (url.trim().isEmpty) return 'Link is required.';
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || (!uri.scheme.startsWith('http'))) {
      return 'Please enter a valid URL (starting with http:// or https://).';
    }
    return null;
  }
}
