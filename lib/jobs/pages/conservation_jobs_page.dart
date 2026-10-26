import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vetconnect/constants.dart';
import 'package:vetconnect/theme/art_deco_theme.dart';
import 'package:vetconnect/theme/art_deco_widgets.dart';

class _ExternalResource {
  final String name;
  final String description;
  final String url;

  const _ExternalResource({
    required this.name,
    required this.description,
    required this.url,
  });
}

class ConservationJobsPage extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function()? loadJobs;

  const ConservationJobsPage({super.key, this.loadJobs});

  @override
  State<ConservationJobsPage> createState() => _ConservationJobsPageState();
}

class _ConservationJobsPageState extends State<ConservationJobsPage> {
  static const List<_ExternalResource> _resources = [
    _ExternalResource(
      name: 'TNC Veteran Hiring Hub',
      description:
          "The Nature Conservancy's dedicated veteran hiring initiative.",
      url: 'https://careers.tnc.org/us/en/veteranhiringhub',
    ),
    _ExternalResource(
      name: 'EPA Careers for Veterans',
      description: 'EPA hiring resources and programs for veterans.',
      url: 'https://www.epa.gov/careers/careers-veterans',
    ),
    _ExternalResource(
      name: 'Habitat for Humanity Veterans Build',
      description:
          "Habitat for Humanity's veteran-focused volunteer and build program.",
      url: 'https://www.habitat.org/volunteer/near-you/veterans-build',
    ),
    _ExternalResource(
      name: 'Salvation Army Veteran Employment Services',
      description: "The Salvation Army's veteran employment services program.",
      url: 'https://cis.salvationarmy.org/cis/ves/',
    ),
    _ExternalResource(
      name: 'Veterans Conservation Corps',
      description: "The Corps Network's Veterans Conservation Corps program.",
      url:
          'https://corpsnetwork.org/programs-initiatives/veterans-conservation-corps/',
    ),
    _ExternalResource(
      name: 'Force Blue',
      description:
          'Deploys veterans on marine conservation and coral reef restoration missions.',
      url: 'https://forceblue.org',
    ),
    _ExternalResource(
      name: 'Hiring Our Heroes Job Board',
      description:
          'U.S. Chamber of Commerce Foundation military and veteran job board.',
      url: 'https://jobs.hiringourheroes.org/',
    ),
  ];

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allJobs = [];
  List<Map<String, dynamic>> _filteredJobs = [];
  List<String> _locationOptions = [];
  String? _selectedLocation;
  bool _isLoading = true;
  bool _loadFailed = false;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilter);
    _loadJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final jobs =
          await (widget.loadJobs?.call() ??
                  Constants.firebaseHelper.getConservationJobs())
              .timeout(const Duration(seconds: 12));
      jobs.sort(
        (a, b) => (a['title'] ?? '').toString().compareTo(
          (b['title'] ?? '').toString(),
        ),
      );
      if (!mounted) return;

      final locations =
          jobs
              .map((job) => (job['locationHint'] ?? '').toString().trim())
              .where((location) => location.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      setState(() {
        _allJobs = jobs;
        _locationOptions = locations;
        _lastUpdated = _newestScrapedAt(jobs);
        _isLoading = false;
      });
      _applyFilter();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  /// The most recent sync timestamp across the listings, used to tell people
  /// how fresh the board is.
  DateTime? _newestScrapedAt(List<Map<String, dynamic>> jobs) {
    DateTime? newest;
    for (final job in jobs) {
      final scrapedAt = job['scrapedAt'];
      if (scrapedAt is! Timestamp) continue;

      final date = scrapedAt.toDate();
      if (newest == null || date.isAfter(newest)) newest = date;
    }
    return newest;
  }

  String _freshnessLabel(DateTime updated) {
    final elapsed = DateTime.now().difference(updated);
    if (elapsed.inMinutes < 60) return 'updated less than an hour ago';
    if (elapsed.inHours < 24) {
      final hours = elapsed.inHours;
      return 'updated $hours hour${hours == 1 ? '' : 's'} ago';
    }
    final days = elapsed.inDays;
    return 'updated $days day${days == 1 ? '' : 's'} ago';
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredJobs = _allJobs.where((job) {
        final title = (job['title'] ?? '').toString().toLowerCase();
        final location = (job['locationHint'] ?? '').toString();

        final matchesQuery =
            query.isEmpty ||
            title.contains(query) ||
            location.toLowerCase().contains(query);
        final matchesLocation =
            _selectedLocation == null || location == _selectedLocation;

        return matchesQuery && matchesLocation;
      }).toList();
    });
  }

  void _onLocationChanged(String? location) {
    setState(() => _selectedLocation = location);
    _applyFilter();
  }

  Future<void> _openLink(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      Constants.showPopup(
        context,
        'Unable to Open Link',
        'We could not open this link right now.',
      );
    }
  }

  Widget _sectionHeading(String title, String subtitle) {
    return PageIntro(title: title, subtitle: subtitle);
  }

  /// Tells people where these listings come from. The publisher names are read
  /// off the documents rather than hardcoded, so adding a second job source to
  /// the sync does not require touching this.
  Widget _sourceNote() {
    final publishers =
        _allJobs
            .map((job) => (job['sourceName'] ?? '').toString().trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (publishers.isEmpty) return const SizedBox.shrink();

    final siteUrl = _allJobs
        .map((job) => (job['sourceSite'] ?? '').toString().trim())
        .firstWhere((url) => url.isNotEmpty, orElse: () => '');

    return RoundedCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: ArtDecoTheme.onSurfaceMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Where these jobs come from',
                  style: GoogleFonts.quicksand(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ArtDecoTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Listings are collected automatically from '
                  '${publishers.join(', ')} and link back to the original '
                  'posting. VeteranConnect does not receive or process '
                  'applications.',
                  style: GoogleFonts.quicksand(
                    fontSize: 12,
                    height: 1.4,
                    color: ArtDecoTheme.onSurfaceMuted,
                  ),
                ),
                if (_lastUpdated != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Automatically ${_freshnessLabel(_lastUpdated!)}.',
                    style: GoogleFonts.quicksand(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: ArtDecoTheme.onSurfaceMuted,
                    ),
                  ),
                ],
                if (siteUrl.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _openLink(siteUrl),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Visit the source →',
                        style: GoogleFonts.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: ArtDecoTheme.backgroundStart,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBadge(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ArtDecoTheme.backgroundStart.withAlpha(28),
      ),
      child: Icon(icon, color: ArtDecoTheme.backgroundStart, size: 20),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: RoundedCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 32),
              const SizedBox(height: 12),
              const Text('Job listings could not load. Please try again.'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadJobs, child: const Text('Retry')),
              const SizedBox(height: 8),
              const Text('You can still browse the Resources tab.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      children: [
        _sectionHeading(
          'Conservation Careers',
          'Veteran-friendly conservation job listings.',
        ),
        const SizedBox(height: 18),
        _sourceNote(),
        const SizedBox(height: 12),
        RoundedCard(
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search by title or location',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                initialValue: _selectedLocation,
                isExpanded: true,
                dropdownColor: ArtDecoTheme.surface,
                style: GoogleFonts.quicksand(
                  color: ArtDecoTheme.onSurface,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                hint: Text(
                  'All locations',
                  style: GoogleFonts.quicksand(
                    color: ArtDecoTheme.onSurfaceMuted,
                  ),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'All locations',
                      style: GoogleFonts.quicksand(
                        color: ArtDecoTheme.onSurface,
                      ),
                    ),
                  ),
                  ..._locationOptions.map(
                    (location) => DropdownMenuItem<String?>(
                      value: location,
                      child: Text(
                        location,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.quicksand(
                          color: ArtDecoTheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
                onChanged: _onLocationChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _filteredJobs.isEmpty
              ? 'NO JOBS FOUND'
              : '${_filteredJobs.length} JOB${_filteredJobs.length == 1 ? '' : 'S'}',
          style: GoogleFonts.quicksand(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: ArtDecoTheme.muted,
          ),
        ),
        const SizedBox(height: 8),
        ..._filteredJobs.map((job) {
          final detailUrl = job['detailUrl'] as String?;
          final applyLink = job['applyLink'] as String?;
          final sourceName = (job['sourceName'] ?? '').toString().trim();

          return Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: RoundedCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _iconBadge(Icons.eco_rounded),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (job['title'] ?? 'Unknown Role').toString(),
                          style: GoogleFonts.quicksand(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: ArtDecoTheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (job['locationHint'] ?? 'Location not available')
                              .toString(),
                        ),
                        if (sourceName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Posted by $sourceName',
                            style: GoogleFonts.quicksand(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                              color: ArtDecoTheme.onSurfaceMuted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: detailUrl == null
                                    ? null
                                    : () => _openLink(detailUrl),
                                child: const Text('Details'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: applyLink == null
                                    ? null
                                    : () => _openLink(applyLink),
                                child: const Text('Apply'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildResourcesTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      children: [
        _sectionHeading(
          'More Resources',
          'Other veteran friendly job resources',
        ),
        const SizedBox(height: 18),
        ..._resources.map(
          (resource) => Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: RoundedCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _iconBadge(CupertinoIcons.link),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(resource.name),
                        const SizedBox(height: 6),
                        Text(resource.description),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _openLink(resource.url),
                            icon: const Icon(
                              CupertinoIcons.arrow_up_right_square,
                            ),
                            label: const Text('Visit site'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: ArtDecoScaffold(
        appBar: AppBar(
          title: const Text('Careers & resources'),
          bottom: TabBar(
            labelColor: ArtDecoTheme.accent,
            unselectedLabelColor: ArtDecoTheme.muted,
            indicatorColor: ArtDecoTheme.accent,
            tabs: const [
              Tab(text: 'Opportunities'),
              Tab(text: 'Resources'),
            ],
          ),
        ),
        child: TabBarView(
          children: [
            _isLoading
                ? const Center(child: CupertinoActivityIndicator(radius: 16))
                : _loadFailed
                ? _buildLoadError()
                : _buildJobsTab(),
            _buildResourcesTab(),
          ],
        ),
      ),
    );
  }
}
