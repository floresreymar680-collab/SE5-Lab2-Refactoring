// lib/models/document_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DocumentModel {
  final String documentId;
  final String pwdId;
  final String fileName;
  final String fileLink;
  final String fileType;
  final String description;
  final String uploadedBy;
  final String uploadedByName;
  final DateTime uploadedAt;

  DocumentModel({
    required this.documentId,
    required this.pwdId,
    required this.fileName,
    required this.fileLink,
    required this.fileType,
    required this.description,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.uploadedAt,
  });

  factory DocumentModel.fromMap(Map<String, dynamic> map, String docId) {
    return DocumentModel(
      documentId: docId,
      pwdId: map['pwdId'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      fileLink: map['fileLink'] as String? ?? '',
      fileType: map['fileType'] as String? ?? 'Other',
      description: map['description'] as String? ?? '',
      uploadedBy: map['uploadedBy'] as String? ?? '',
      uploadedByName: map['uploadedByName'] as String? ?? '',
      uploadedAt: map['uploadedAt'] is Timestamp
          ? (map['uploadedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  factory DocumentModel.fromDocument(DocumentSnapshot doc) {
    return DocumentModel.fromMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pwdId': pwdId,
      'fileName': fileName,
      'fileLink': fileLink,
      'fileType': fileType,
      'description': description,
      'uploadedBy': uploadedBy,
      'uploadedByName': uploadedByName,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
    };
  }

  IconData get fileIcon {
    switch (fileType) {
      case 'PDF':
        return Icons.picture_as_pdf_outlined;
      case 'Image':
        return Icons.image_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color fileColor(BuildContext context) {
    switch (fileType) {
      case 'PDF':
        return Colors.red;
      case 'Image':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
