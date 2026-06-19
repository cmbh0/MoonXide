import 'package:flutter/material.dart';
import '../../app/mx_widgets.dart';
import '../../core/services/app_state.dart';
import '../token_gate/token_gate_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? user;
  List<Map<String, dynamic>> repos = [];
  List<Map<String, dynamic>> starred = [];
  List<Map<String, dynamic>> followers = [];
  List<Map<String, dynamic>> following = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gh = widget.state.github;
    final login = widget.state.login;
    if (gh == null || login == null) return;
    setState(() { loading = true; error = null; });
    try {
      final u = widget.state.currentUser ?? await gh.getCurrentUser();
      final rs = await gh.listRepositories();
      final st = await gh.listStarredRepositories(perPage: 60);
      final fs = await gh.listFollowers(login, perPage: 50);
      final fg = await gh.listFollowing(login, perPage: 50);
      if (!mounted) return;
      setState(() {
        user = u;
        repos = rs;
        starred = st;
        followers = fs;
        following = fg;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { error = '$e'; loading = false; });
    }
  }

  int get repoStars => repos.fold<int>(0, (s, r) => s + ((r['stargazers_count'] as num?)?.toInt() ?? 0));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final u = user ?? widget.state.currentUser ?? {};
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Row(children: [
                    MxIconBtn(icon: Icons.arrow_back_rounded, onPressed: () => Navigator.pop(context)),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('GitHub 主页', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                    MxIconBtn(
                      icon: Icons.switch_account_rounded,
                      tooltip: '管理多账号',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const TokenGateScreen()),
                        ).then((_) => _load());
                      },
                    ),
                    MxIconBtn(icon: Icons.refresh_rounded, onPressed: _load),
                  ]),
                  const SizedBox(height: 14),
                  MxGlass(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundImage: widget.state.avatarUrl == null ? null : NetworkImage(widget.state.avatarUrl!),
                          child: widget.state.avatarUrl == null ? const Icon(Icons.person_rounded, size: 38) : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${u['name'] ?? widget.state.login ?? 'GitHub User'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text('@${u['login'] ?? widget.state.login ?? ''}', style: TextStyle(color: scheme.onSurface.withOpacity(0.55), fontWeight: FontWeight.w700)),
                          if ((u['bio'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('${u['bio']}', style: TextStyle(color: scheme.onSurface.withOpacity(0.75))),
                          ],
                        ])),
                      ]),
                      const SizedBox(height: 14),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _InfoChip(icon: Icons.people_rounded, label: '${followers.length} followers'),
                        _InfoChip(icon: Icons.person_add_alt_rounded, label: '${following.length} following'),
                        _InfoChip(icon: Icons.folder_rounded, label: '${repos.length} repos'),
                        _InfoChip(icon: Icons.star_rounded, label: '$repoStars repo stars'),
                        _InfoChip(icon: Icons.favorite_rounded, label: '${starred.length} starred'),
                      ]),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: MxButton(
                              label: '切换/管理多账号',
                              icon: Icons.switch_account_rounded,
                              small: true,
                              filled: false,
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const TokenGateScreen()),
                                ).then((_) => _load());
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: MxButton(
                              label: '退出当前登录',
                              icon: Icons.logout_rounded,
                              color: Colors.redAccent,
                              small: true,
                              filled: false,
                              onPressed: () async {
                                final ok = await MxDialog.show(
                                  context,
                                  title: '退出登录',
                                  content: '确认退出当前账号 @${widget.state.login} 吗？',
                                  confirmLabel: '退出',
                                  cancelLabel: '取消',
                                  confirmColor: Colors.redAccent,
                                );
                                if (ok) {
                                  await widget.state.logout();
                                  if (mounted) Navigator.pop(context);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      if ((u['company'] ?? '').toString().isNotEmpty || (u['location'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        if ((u['company'] ?? '').toString().isNotEmpty) _Meta(Icons.apartment_rounded, '${u['company']}'),
                        if ((u['location'] ?? '').toString().isNotEmpty) _Meta(Icons.location_on_rounded, '${u['location']}'),
                      ],
                    ]),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    MxCard(child: Text(error!, style: TextStyle(color: scheme.error, fontSize: 12))),
                  ],
                  const MxSectionLabel('热门仓库'),
                  ...repos.take(12).map((r) => _RepoCard(repo: r)),
                  const MxSectionLabel('收藏 Starred'),
                  ...starred.take(12).map((r) => _RepoCard(repo: r, compact: true)),
                ],
              ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withOpacity(0.22)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: scheme.primary),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.primary)),
      ]),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Row(children: [
      Icon(icon, size: 15, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45)),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62)))),
    ]),
  );
}

class _RepoCard extends StatelessWidget {
  const _RepoCard({required this.repo, this.compact = false});
  final Map<String, dynamic> repo;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = repo['name'] ?? '';
    final desc = repo['description'];
    final lang = repo['language'];
    final stars = repo['stargazers_count'] ?? 0;
    final forks = repo['forks_count'] ?? 0;
    final private = repo['private'] == true;
    return MxCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(private ? Icons.lock_rounded : Icons.book_rounded, size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('$name', style: const TextStyle(fontWeight: FontWeight.w900))),
          if (private) const MxBadge('PRIVATE') else const MxBadge('PUBLIC'),
        ]),
        if (desc != null && '$desc'.isNotEmpty && !compact) ...[
          const SizedBox(height: 8),
          Text('$desc', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.62))),
        ],
        const SizedBox(height: 10),
        Wrap(spacing: 12, runSpacing: 6, children: [
          if (lang != null) _SmallMeta(Icons.circle, '$lang'),
          _SmallMeta(Icons.star_rounded, '$stars'),
          _SmallMeta(Icons.call_split_rounded, '$forks'),
          _SmallMeta(Icons.update_rounded, '${repo['updated_at'] ?? ''}'.split('T').first),
        ]),
      ]),
    );
  }
}

class _SmallMeta extends StatelessWidget {
  const _SmallMeta(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45)),
    const SizedBox(width: 4),
    Text(text, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55), fontWeight: FontWeight.w700)),
  ]);
}