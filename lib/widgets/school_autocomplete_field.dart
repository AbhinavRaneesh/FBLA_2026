import 'dart:async';

import 'package:flutter/material.dart';

import '../models/school.dart';
import '../services/school_search_service.dart';

class SchoolAutocompleteField extends StatefulWidget {
  final String? stateAbbr;
  final TextEditingController controller;
  final FocusNode focusNode;
  final School? selectedSchool;
  final ValueChanged<School?> onSchoolChanged;
  final Color accentColor;
  final Color hintColor;
  final Color textColor;
  final Color fieldBackgroundColor;
  final Color borderColor;
  final Color focusedBorderColor;

  const SchoolAutocompleteField({
    super.key,
    required this.stateAbbr,
    required this.controller,
    required this.focusNode,
    required this.selectedSchool,
    required this.onSchoolChanged,
    this.accentColor = const Color(0xFF4D9DE0),
    this.hintColor = const Color(0x73FFFFFF),
    this.textColor = Colors.white,
    this.fieldBackgroundColor = const Color(0x0AFFFFFF),
    this.borderColor = const Color(0x1AFFFFFF),
    this.focusedBorderColor = const Color(0xE64D9DE0),
  });

  @override
  State<SchoolAutocompleteField> createState() =>
      _SchoolAutocompleteFieldState();
}

class _SchoolAutocompleteFieldState extends State<SchoolAutocompleteField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<School> _options = const [];
  bool _isSearching = false;
  String? _searchError;
  Timer? _debounce;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
    widget.controller.addListener(_handleTextChange);
  }

  @override
  void didUpdateWidget(covariant SchoolAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stateAbbr != widget.stateAbbr) {
      _hideOverlay();
      setState(() {
        _options = const [];
        _searchError = null;
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _hideOverlay();
    widget.focusNode.removeListener(_handleFocusChange);
    widget.controller.removeListener(_handleTextChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (!widget.focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        _hideOverlay();
      });
    } else if (_options.isNotEmpty) {
      _showOverlay();
    }
    setState(() {});
  }

  void _handleTextChange() {
    final text = widget.controller.text;
    if (widget.selectedSchool != null &&
        text.trim() != widget.selectedSchool!.name) {
      widget.onSchoolChanged(null);
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      _runSearch(text);
    });
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    _lastQuery = trimmed;

    if (trimmed.isEmpty) {
      if (!mounted) return;
      setState(() {
        _options = const [];
        _isSearching = false;
        _searchError = null;
      });
      _hideOverlay();
      return;
    }

    if (trimmed.length < 2) {
      if (!mounted) return;
      setState(() {
        _options = const [];
        _isSearching = false;
        _searchError = 'Type at least 2 letters to search';
      });
      if (widget.focusNode.hasFocus) _showOverlay();
      return;
    }

    if (widget.stateAbbr == null || widget.stateAbbr!.isEmpty) {
      if (!mounted) return;
      setState(() {
        _options = const [];
        _isSearching = false;
        _searchError = 'Select your state first';
      });
      _showOverlay();
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    _showOverlay();

    try {
      final results = await SchoolSearchService.instance.search(
        stateAbbr: widget.stateAbbr!,
        query: trimmed,
      );
      if (!mounted || _lastQuery != trimmed) return;
      setState(() {
        _options = results;
        _isSearching = false;
        _searchError =
            results.isEmpty ? 'No schools found — try another spelling' : null;
      });
      if (widget.focusNode.hasFocus) {
        _showOverlay();
      }
    } on SchoolSearchException catch (error) {
      if (!mounted || _lastQuery != trimmed) return;
      setState(() {
        _options = const [];
        _isSearching = false;
        _searchError = error.message;
      });
      _showOverlay();
    } catch (_) {
      if (!mounted || _lastQuery != trimmed) return;
      setState(() {
        _options = const [];
        _isSearching = false;
        _searchError = 'Could not load schools. Please try again.';
      });
      _showOverlay();
    }
  }

  void _selectSchool(School school) {
    widget.controller.text = school.name;
    widget.onSchoolChanged(school);
    _hideOverlay();
    widget.focusNode.unfocus();
    setState(() {});
  }

  void _showOverlay() {
    _hideOverlay();
    if (!widget.focusNode.hasFocus) return;
    if (_options.isEmpty && !_isSearching && _searchError == null) return;

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final width = renderBox.size.width;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 56),
            child: Material(
              color: Colors.transparent,
              child: _buildOptionsPanel(),
            ),
          ),
        );
      },
    );
    overlay.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildOptionsPanel() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: const Color(0xFF0E2A56),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.accentColor.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _isSearching
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.stateAbbr == null
                        ? 'Select your state first'
                        : widget.stateAbbr == 'UT'
                            ? 'Searching Utah schools...'
                            : 'School list available for Utah only',
                    style: TextStyle(
                      color: widget.textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : _options.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    _searchError ?? 'Start typing your school name',
                    style: TextStyle(
                      color: widget.hintColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shrinkWrap: true,
                  itemCount: _options.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  itemBuilder: (context, index) {
                    final school = _options[index];
                    return InkWell(
                      onTap: () => _selectSchool(school),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              school.name,
                              style: TextStyle(
                                color: widget.textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (school.city.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${school.city}, ${school.state}',
                                style: TextStyle(
                                  color: widget.hintColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;
    final borderColor =
        focused ? widget.focusedBorderColor : widget.borderColor;

    return CompositedTransformTarget(
      link: _layerLink,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: widget.fieldBackgroundColor,
          border: Border.all(color: borderColor),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.22),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(
                Icons.apartment_rounded,
                color: focused
                    ? widget.accentColor
                    : Colors.white.withValues(alpha: 0.55),
                size: 20,
              ),
            ),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(
                  color: widget.textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                cursorColor: widget.accentColor,
                decoration: InputDecoration(
                  hintText: widget.stateAbbr == null
                      ? 'Select state first'
                      : widget.stateAbbr == 'UT'
                          ? 'Search Utah school name'
                          : 'Select Utah for school search',
                  hintStyle: TextStyle(
                    color: widget.hintColor,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (widget.selectedSchool != null)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.verified_rounded,
                  color: widget.accentColor,
                  size: 20,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Icon(
                  Icons.search_rounded,
                  color: Colors.white.withValues(alpha: 0.45),
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
