import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tasks_page.dart';
import 'user_settings_main_page.dart';

class SitesPage extends StatefulWidget {
  const SitesPage({super.key});

  @override
  State<SitesPage> createState() => _SitesPageState();
}

class _SitesPageState extends State<SitesPage> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<String> _selectedSites = [];

  // Current site shown in the site switcher.
  int _currentSiteIndex = 0;

  final List<_SiteInfo> _allSites = const [
    _SiteInfo(
      keyName: 'seofast',
      name: 'SEO Fast',
      description: 'Complete available SEO Fast tasks.',
      icon: Icons.search_rounded,
      referralUrl: 'https://seo-fast.ru/?r=3151488',
    ),
    _SiteInfo(
      keyName: 'aviso',
      name: 'Aviso',
      description: 'Complete available Aviso tasks.',
      icon: Icons.campaign_rounded,
      referralUrl: 'https://aviso.bz/?r=khroba_242',
    ),
    _SiteInfo(
      keyName: 'socpublic',
      name: 'SocPublic',
      description: 'Complete available SocPublic tasks.',
      icon: Icons.public_rounded,
      referralUrl: 'https://socpublic.com/?i=9565193&slide=3',
    ),
    _SiteInfo(
      keyName: 'unu',
      name: 'Unu',
      description: 'Complete available Unu tasks.',
      icon: Icons.bolt_rounded,
      referralUrl: 'https://unu.im/re/4409943/work',
    ),
    _SiteInfo(
      keyName: 'ipweb',
      name: 'IPWeb',
      description: 'Complete available IPWeb tasks.',
      icon: Icons.language_rounded,
      referralUrl: 'https://www.ipweb.ru/?gg102001293699541602847',
    ),
    _SiteInfo(
      keyName: 'taskpay',
      name: 'Taskpay',
      description: 'Complete available Taskpay tasks.',
      icon: Icons.payments_outlined,
      referralUrl: 'https://taskpay.ru/?ref=3430487',
    ),
    _SiteInfo(
      keyName: 'fastsmm',
      name: 'FastSMM',
      description: 'Complete available FastSMM tasks.',
      icon: Icons.speed_rounded,
      referralUrl: 'https://fastsmm.ru/u/256455',
    ),
    _SiteInfo(
      keyName: 'profittask',
      name: 'Profittask',
      description: 'Complete available Profittask tasks.',
      icon: Icons.trending_up_rounded,
      referralUrl: 'https://profittask.com/?from=1425298',
    ),
    _SiteInfo(
      keyName: 'wmrfast',
      name: 'WMRFast',
      description: 'Complete available WMRFast tasks.',
      icon: Icons.account_balance_wallet_outlined,
      referralUrl: 'https://wmrfast.com/?r=2360765',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    try {
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _selectedSites = [];
            _currentSiteIndex = 0;
          });
        }
        return;
      }

      final data = await supabase
          .from('user_settings')
          .select('sites')
          .eq('user_id', userId)
          .maybeSingle();

      List<String> loadedSites = [];

      if (data != null && data['sites'] != null) {
        final rawSites = data['sites'];

        if (rawSites is List) {
          loadedSites = rawSites
              .map((site) => site.toString().trim().toLowerCase())
              .where((site) => site.isNotEmpty)
              .toList();
        }
      }

      if (mounted) {
        setState(() {
          _selectedSites = loadedSites;
          _currentSiteIndex = 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading sites: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading your sites: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Returns only the selected sites that actually exist
  // in our supported sites list.
  List<_SiteInfo> _getSelectedSiteInfos() {
    final List<_SiteInfo> sites = [];

    for (final siteKey in _selectedSites) {
      final site = _findSite(siteKey);

      if (site != null) {
        sites.add(site);
      }
    }

    return sites;
  }

  // Move to the next selected site.
  // When we reach the last site, go back to the first one.
  void _goToNextSite() {
    final sites = _getSelectedSiteInfos();

    if (sites.isEmpty) {
      return;
    }

    setState(() {
      if (_currentSiteIndex >= sites.length - 1) {
        _currentSiteIndex = 0;
      } else {
        _currentSiteIndex++;
      }
    });
  }

  Future<void> _openTasks(_SiteInfo site) async {
    if (!_selectedSites.contains(site.keyName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This site is not selected in your account settings.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TasksPage(
          siteName: site.keyName,
        ),
      ),
    );
  }

  Future<void> _openReferral(_SiteInfo site) async {
    final uri = Uri.tryParse(site.referralUrl);

    if (uri == null) {
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the site link.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const UserSettingsMainPage(),
      ),
    ).then((_) {
      _loadSites();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFE85D24),
          onRefresh: _loadSites,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFE85D24),
                  ),
                )
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    22,
                    20,
                    32,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 700,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 22),
                          _buildSummaryCard(),
                          const SizedBox(height: 28),
                          _buildAvailableSitesHeader(),
                          const SizedBox(height: 14),
                          if (_selectedSites.isEmpty)
                            _buildNoSitesCard()
                          else
                            _buildCurrentSiteSection(),
                          const SizedBox(height: 28),
                          _buildAllSitesInfo(),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildAvailableSitesHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available sites',
                style: TextStyle(
                  color: Color(0xFF171717),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Choose a site to view its available tasks.',
                style: TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: _openSettings,
          icon: const Icon(
            Icons.settings_outlined,
            size: 18,
          ),
          label: const Text('Settings'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFE85D24),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentSiteSection() {
    final sites = _getSelectedSiteInfos();

    if (sites.isEmpty) {
      return _buildNoSitesCard();
    }

    if (_currentSiteIndex >= sites.length) {
      _currentSiteIndex = 0;
    }

    final currentSite = sites[_currentSiteIndex];

    return Column(
      children: [
        // Site position indicator.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentSiteIndex + 1} / ${sites.length}',
                style: const TextStyle(
                  color: Color(0xFFE85D24),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Current site card.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(currentSite.keyName),
            child: _buildSiteCard(currentSite),
          ),
        ),

        const SizedBox(height: 14),

        // Circular navigation button.
        _buildNextSiteButton(
          currentSite: currentSite,
          totalSites: sites.length,
        ),
      ],
    );
  }

  Widget _buildNextSiteButton({
    required _SiteInfo currentSite,
    required int totalSites,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _goToNextSite,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFFFD4BF),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Color(0xFFE85D24),
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Next site',
                      style: TextStyle(
                        color: Color(0xFF171717),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      totalSites > 1
                          ? 'Switch from ${currentSite.name} to the next site'
                          : 'Only one selected site',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE85D24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _SiteInfo? _findSite(String keyName) {
    for (final site in _allSites) {
      if (site.keyName == keyName.toLowerCase()) {
        return site;
      }
    }

    return null;
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sites',
                style: TextStyle(
                  color: Color(0xFF171717),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Manage the platforms where you complete tasks.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _openSettings,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.settings_rounded,
                color: Color(0xFF242424),
                size: 21,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final int count = _selectedSites.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF2EA),
            Color(0xFFFFE6D8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFD4BF),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE85D24).withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.language_rounded,
              color: Color(0xFFE85D24),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count selected ${count == 1 ? 'site' : 'sites'}',
                  style: const TextStyle(
                    color: Color(0xFF171717),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your selected sites are used to show relevant tasks.',
                  style: TextStyle(
                    color: Color(0xFF725747),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteCard(_SiteInfo site) {
    final bool selected = _selectedSites.contains(site.keyName);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 280,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? const Color(0xFFFFD2BD) : const Color(0xFFE8E8E8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0E8),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    site.icon,
                    color: const Color(0xFFE85D24),
                    size: 27,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        site.name,
                        style: const TextStyle(
                          color: Color(0xFF171717),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selected ? 'Selected' : 'Not selected',
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFFE85D24)
                              : const Color(0xFF999999),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0E8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        color: Color(0xFFE85D24),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              site.description,
              style: const TextStyle(
                color: Color(0xFF777777),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const Spacer(),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: selected ? () => _openTasks(site) : null,
                      icon: const Icon(
                        Icons.task_alt_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        'View Tasks',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE85D24),
                        disabledBackgroundColor: const Color(0xFFEDEDED),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: const Color(0xFF999999),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 46,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => _openReferral(site),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE85D24),
                      side: const BorderSide(
                        color: Color(0xFFFFD4C1),
                      ),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: const Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSitesCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE8E8E8),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.language_rounded,
              color: Color(0xFFE85D24),
              size: 30,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'No sites selected',
            style: TextStyle(
              color: Color(0xFF171717),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose the sites you want to work on from your settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF777777),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openSettings,
            icon: const Icon(
              Icons.settings_outlined,
              size: 18,
            ),
            label: const Text(
              'Open Settings',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE85D24),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllSitesInfo() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE8E8E8),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFE85D24),
            size: 21,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'You can manage your selected sites from Settings. '
              'Only selected sites will appear in your task workflow.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SiteInfo {
  final String keyName;
  final String name;
  final String description;
  final IconData icon;
  final String referralUrl;

  const _SiteInfo({
    required this.keyName,
    required this.name,
    required this.description,
    required this.icon,
    required this.referralUrl,
  });
}
