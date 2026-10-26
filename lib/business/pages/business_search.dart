import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vetconnect/constants.dart';

class BusinessSearch extends StatefulWidget {
  final ValueChanged<List<Map<String, dynamic>>>? onResultsChanged;
  final ValueChanged<bool>? onSearchStateChanged;
  final VoidCallback? onAiSearchTap;
  final ValueChanged<String>? onQuerySubmitted;

  /// Runs the search instead of the default directory-wide lookup.
  ///
  /// The map page supplies this so a search can be scoped to the ZIPs the
  /// user is browsing; when null, search covers the whole directory.
  final Future<List<Map<String, dynamic>>> Function(String query)? onSearch;

  /// Shrinks the field for use as a map overlay, where vertical space is
  /// shared with the other map controls.
  final bool dense;

  const BusinessSearch({
    super.key,
    this.onResultsChanged,
    this.onSearchStateChanged,
    this.onAiSearchTap,
    this.onQuerySubmitted,
    this.onSearch,
    this.dense = false,
  });

  @override
  State<BusinessSearch> createState() => _BusinessSearchState();
}

class _BusinessSearchState extends State<BusinessSearch> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  int _searchRequestId = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setLoading(bool value) {
    setState(() => _isLoading = value);
    widget.onSearchStateChanged?.call(value);
  }

  Future<void> _performSearch(String query) async {
    final requestId = ++_searchRequestId;
    if (query.trim().isEmpty) {
      // Emptying the box is how people expect to dismiss results, so report
      // the empty set rather than silently leaving the last ones on screen.
      _setLoading(false);
      widget.onResultsChanged?.call(const []);
      return;
    }

    widget.onQuerySubmitted?.call(query.trim());
    FocusManager.instance.primaryFocus?.unfocus();
    _setLoading(true);
    try {
      final override = widget.onSearch;
      final results = override != null
          ? await override(query.trim())
          : await Constants.firebaseHelper.searchForBusiness(query.trim());
      final mappedResults = results.whereType<Map<String, dynamic>>().toList();

      if (!mounted || requestId != _searchRequestId) return;
      _setLoading(false);
      widget.onResultsChanged?.call(mappedResults);

      if (mappedResults.isEmpty) {
        Constants.showPopup(
          context,
          'No Results',
          'No businesses matched your search.',
        );
      }
    } catch (e) {
      if (!mounted || requestId != _searchRequestId) return;
      _setLoading(false);
      print('Search error: $e');
      Constants.showPopup(
        context,
        'Search Error',
        'Unable to complete your search right now. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // IconButton reserves a 48px tap target, which sets the field's height
    // regardless of contentPadding -- so the dense variant has to shrink the
    // icons too, not just the padding.
    final iconConstraints = widget.dense
        ? const BoxConstraints(minWidth: 42, minHeight: 38)
        : null;
    final iconPadding = widget.dense ? EdgeInsets.zero : null;

    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: _performSearch,
      onChanged: (value) {
        if (value.trim().isEmpty) _performSearch(value);
      },
      style: widget.dense ? const TextStyle(fontSize: 14) : null,
      decoration: InputDecoration(
        isDense: widget.dense,
        contentPadding: widget.dense
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
            : null,
        prefixIconConstraints: iconConstraints,
        suffixIconConstraints: iconConstraints,
        hintText: 'Find veteran-owned services',
        prefixIcon: IconButton(
          onPressed: () => _performSearch(_searchController.text),
          padding: iconPadding,
          constraints: iconConstraints,
          visualDensity: widget.dense ? VisualDensity.compact : null,
          iconSize: widget.dense ? 20 : null,
          icon: const Icon(Icons.search),
        ),
        suffixIcon: _isLoading
            ? Padding(
                padding: EdgeInsets.all(widget.dense ? 10 : 14),
                child: const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : widget.onAiSearchTap == null
            ? null
            : IconButton(
                onPressed: widget.onAiSearchTap,
                tooltip: 'AI Search',
                padding: iconPadding,
                constraints: iconConstraints,
                visualDensity: widget.dense ? VisualDensity.compact : null,
                iconSize: widget.dense ? 20 : null,
                icon: const Icon(CupertinoIcons.sparkles),
              ),
      ),
    );
  }
}
