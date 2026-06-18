import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../data/document_library_catalog.dart';
import '../main.dart' show appBackgroundGradient, fblaGold, fblaNavy;

class DocumentLibraryScreen extends StatefulWidget {
  const DocumentLibraryScreen({super.key});

  @override
  State<DocumentLibraryScreen> createState() => _DocumentLibraryScreenState();
}

class _DocumentLibraryScreenState extends State<DocumentLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DocumentLibraryCategory _selectedCategory = DocumentLibraryCategory.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DocumentLibraryItem> get _filteredDocuments {
    final query = _searchQuery.trim().toLowerCase();
    final items = DocumentLibraryCatalog.sortedAlphabetically();

    return items.where((doc) {
      final matchesCategory = _selectedCategory == DocumentLibraryCategory.all ||
          doc.category == _selectedCategory;
      if (!matchesCategory) return false;

      if (query.isEmpty) return true;

      return doc.title.toLowerCase().contains(query) ||
          doc.subtitle.toLowerCase().contains(query) ||
          doc.category.label.toLowerCase().contains(query);
    }).toList();
  }

  void _openDocument(DocumentLibraryItem document) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentPdfViewerScreen(document: document),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final documents = _filteredDocuments;

    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        title: const Text('Document Library'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search documents...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha:0.55)),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha:0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: DocumentLibraryCategory.values.map((category) {
                  final selected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category.label),
                      selected: selected,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: selected ? fblaNavy : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                      backgroundColor: Colors.white.withValues(alpha:0.08),
                      selectedColor: fblaGold,
                      side: BorderSide(
                        color: selected
                            ? fblaGold.withValues(alpha:0.8)
                            : Colors.white24,
                      ),
                      onSelected: (_) {
                        setState(() => _selectedCategory = category);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: documents.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: documents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final doc = documents[index];
                        return _DocumentTile(
                          document: doc,
                          onTap: () => _openDocument(doc),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_off_outlined,
              size: 56,
              color: Colors.white.withValues(alpha:0.35),
            ),
            const SizedBox(height: 16),
            const Text(
              'No documents found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term or filter.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha:0.65),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final DocumentLibraryItem document;
  final VoidCallback onTap;

  const _DocumentTile({
    required this.document,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0B1624),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: fblaGold.withValues(alpha:0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: fblaGold.withValues(alpha:0.35)),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: fblaGold,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  document.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

class DocumentPdfViewerScreen extends StatefulWidget {
  final DocumentLibraryItem document;

  const DocumentPdfViewerScreen({
    super.key,
    required this.document,
  });

  @override
  State<DocumentPdfViewerScreen> createState() =>
      _DocumentPdfViewerScreenState();
}

class _DocumentPdfViewerScreenState extends State<DocumentPdfViewerScreen> {
  late final Future<Uint8List> _pdfBytesFuture;

  @override
  void initState() {
    super.initState();
    _pdfBytesFuture = _loadPdfBytes();
  }

  Future<Uint8List> _loadPdfBytes() async {
    final data = await rootBundle.load(widget.document.assetPath);
    return data.buffer.asUint8List();
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return PreferredSize(
      preferredSize: Size.fromHeight(60 + topPadding),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1D4E89),
                Color(0xFF0F2A4A),
                Color(0xFF07111F),
              ],
            ),
            border: Border(
              bottom: BorderSide(color: fblaGold, width: 2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(8, topPadding + 6, 12, 10),
          child: Row(
            children: [
              Material(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.maybePop(context),
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: fblaGold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: fblaGold.withValues(alpha: 0.45)),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: fblaGold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.document.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(context),
      body: FutureBuilder<Uint8List>(
        future: _pdfBytesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Container(
              decoration: const BoxDecoration(gradient: appBackgroundGradient),
              child: const Center(
                child: CircularProgressIndicator(color: fblaGold),
              ),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Container(
              decoration: const BoxDecoration(gradient: appBackgroundGradient),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white54,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Could not open this document',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Stop the app and run a full rebuild so bundled PDFs reload.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return SfPdfViewer.memory(snapshot.data!);
        },
      ),
    );
  }
}
