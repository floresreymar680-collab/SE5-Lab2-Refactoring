// lib/screens/shared/document_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_constants.dart';
import '../../models/document_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/document_service.dart';
import '../../utils/uuid_utils.dart';

class DocumentScreen extends StatefulWidget {
  final String pwdId;
  final String pwdFullName;

  const DocumentScreen({
    super.key,
    required this.pwdId,
    required this.pwdFullName,
  });

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  final DocumentService _documentService = DocumentService();

  List<DocumentModel> _documents = [];
  bool _loading = true;
  bool _saving = false;

  // ── Form controllers ──────────────────────────────────────────────────────
  final _fileNameCtrl = TextEditingController();
  final _fileLinkCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  String _selectedFileType = 'PDF';
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void dispose() {
    _fileNameCtrl.dispose();
    _fileLinkCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    setState(() => _loading = true);
    final docs = await _documentService.fetchDocumentsForPWD(widget.pwdId);
    if (mounted) {
      setState(() {
        _documents = docs;
        _loading = false;
      });
    }
  }

  // ── Show add document bottom sheet ────────────────────────────────────────
  void _showAddDocumentSheet() {
    _fileNameCtrl.clear();
    _fileLinkCtrl.clear();
    _descriptionCtrl.clear();
    _selectedFileType = 'PDF';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AddDocumentSheet(
        fileNameCtrl: _fileNameCtrl,
        fileLinkCtrl: _fileLinkCtrl,
        descriptionCtrl: _descriptionCtrl,
        formKey: _formKey,
        selectedFileType: _selectedFileType,
        onFileTypeChanged: (v) => setState(() => _selectedFileType = v!),
        onSave: _saveDocument,
        saving: _saving,
        documentService: _documentService,
      ),
    );
  }

  Future<void> _saveDocument() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final linkError = _documentService.validateLink(_fileLinkCtrl.text);
    if (linkError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(linkError),
          backgroundColor: const Color(AppConstants.dangerRed),
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.currentUser!;

    setState(() => _saving = true);

    final success = await _documentService.addDocument(
      pwdId: widget.pwdId,
      fileName: _fileNameCtrl.text,
      fileLink: _fileLinkCtrl.text,
      fileType: _selectedFileType,
      description: _descriptionCtrl.text,
      uploadedBy: user.userId,
      uploadedByName: user.fullName,
      role: user.role,
    );

    if (mounted) {
      setState(() => _saving = false);
      Navigator.of(context).pop(); // close bottom sheet

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Document link added successfully.'
                : 'Failed to add document. Please try again.',
          ),
          backgroundColor: success
              ? const Color(AppConstants.successGreen)
              : const Color(AppConstants.dangerRed),
        ),
      );

      if (success) _loadDocuments();
    }
  }

  Future<void> _confirmDelete(DocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Delete "${doc.fileName}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.dangerRed),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await _documentService.deleteDocument(doc.documentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Document deleted.' : 'Failed to delete document.',
            ),
            backgroundColor: success
                ? const Color(AppConstants.successGreen)
                : const Color(AppConstants.dangerRed),
          ),
        );
        if (success) _loadDocuments();
      }
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final canAdd = auth.isAdmin || auth.isBarangayStaff;

    return GestureDetector(
      onTap: () => context.read<AuthProvider>().resetActivityTimer(),
      child: Scaffold(
        backgroundColor: const Color(AppConstants.backgroundGray),
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Documents', style: TextStyle(fontSize: 16)),
              Text(
                widget.pwdFullName,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        floatingActionButton: canAdd
            ? FloatingActionButton.extended(
                onPressed: _showAddDocumentSheet,
                backgroundColor: const Color(AppConstants.navyBlue),
                icon: const Icon(Icons.add_link, color: Colors.white),
                label: const Text('Add Document Link',
                    style: TextStyle(color: Colors.white)),
              )
            : null,
        body: Column(
          children: [
            // Info bar
            Container(
              width: double.infinity,
              color:
                  const Color(AppConstants.lightBlue).withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 15, color: Color(AppConstants.lightBlue)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Paste a Google Drive, OneDrive, or any public link to the document.',
                      style: TextStyle(
                          fontSize: 12, color: Color(AppConstants.lightBlue)),
                    ),
                  ),
                  Text(
                    '${_documents.length} file(s)',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(AppConstants.lightBlue),
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _documents.isEmpty
                      ? _buildEmptyState(canAdd)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _documents.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _DocumentTile(
                            doc: _documents[i],
                            isAdmin: isAdmin,
                            onOpen: () => _openLink(_documents[i].fileLink),
                            onDelete: () => _confirmDelete(_documents[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool canAdd) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No documents linked yet.',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add a link to a Google Drive or OneDrive file.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (canAdd) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showAddDocumentSheet,
              icon: const Icon(Icons.add_link),
              label: const Text('Add Document Link'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Add Document Bottom Sheet ─────────────────────────────────────────────────
class _AddDocumentSheet extends StatefulWidget {
  final TextEditingController fileNameCtrl;
  final TextEditingController fileLinkCtrl;
  final TextEditingController descriptionCtrl;
  final GlobalKey<FormState> formKey;
  final String selectedFileType;
  final ValueChanged<String?> onFileTypeChanged;
  final VoidCallback onSave;
  final bool saving;
  final DocumentService documentService;

  const _AddDocumentSheet({
    required this.fileNameCtrl,
    required this.fileLinkCtrl,
    required this.descriptionCtrl,
    required this.formKey,
    required this.selectedFileType,
    required this.onFileTypeChanged,
    required this.onSave,
    required this.saving,
    required this.documentService,
  });

  @override
  State<_AddDocumentSheet> createState() => _AddDocumentSheetState();
}

class _AddDocumentSheetState extends State<_AddDocumentSheet> {
  late String _fileType;

  @override
  void initState() {
    super.initState();
    _fileType = widget.selectedFileType;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: widget.formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.add_link,
                      color: Color(AppConstants.navyBlue)),
                  const SizedBox(width: 10),
                  const Text(
                    'Add Document Link',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(AppConstants.navyBlue),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              // Document Name
              const Text('Document Name *',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey)),
              const SizedBox(height: 4),
              TextFormField(
                controller: widget.fileNameCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. Medical Certificate, Birth Certificate',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Document name is required'
                    : null,
              ),
              const SizedBox(height: 14),

              // File Type
              const Text('File Type *',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _fileType,
                decoration: const InputDecoration(),
                items: AppConstants.documentTypes
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() => _fileType = v!);
                  widget.onFileTypeChanged(v);
                },
              ),
              const SizedBox(height: 14),

              // File Link
              const Text('Document Link (URL) *',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey)),
              const SizedBox(height: 4),
              TextFormField(
                controller: widget.fileLinkCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: 'https://drive.google.com/...',
                  prefixIcon: Icon(Icons.link, size: 18),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Link is required';
                  }
                  return widget.documentService.validateLink(v);
                },
              ),
              const SizedBox(height: 14),

              // Description
              const Text('Description (optional)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey)),
              const SizedBox(height: 4),
              TextFormField(
                controller: widget.descriptionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'e.g. Issued by Barangay Health Center, 2024',
                ),
              ),
              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.saving ? null : widget.onSave,
                  icon: widget.saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label:
                      Text(widget.saving ? 'Saving...' : 'Save Document Link'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Document Tile ─────────────────────────────────────────────────────────────
class _DocumentTile extends StatelessWidget {
  final DocumentModel doc;
  final bool isAdmin;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _DocumentTile({
    required this.doc,
    required this.isAdmin,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: doc.fileColor(context).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            doc.fileIcon,
            color: doc.fileColor(context),
            size: 22,
          ),
        ),
        title: Text(
          doc.fileName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text('Type: ${doc.fileType}', style: const TextStyle(fontSize: 12)),
            if (doc.description.isNotEmpty)
              Text(doc.description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            Text(
              'By: ${doc.uploadedByName}  •  ${_fmt(doc.uploadedAt)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 20),
              tooltip: 'Open Link',
              color: const Color(AppConstants.lightBlue),
              onPressed: onOpen,
            ),
            if (isAdmin)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Delete',
                color: const Color(AppConstants.dangerRed),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    return '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}
