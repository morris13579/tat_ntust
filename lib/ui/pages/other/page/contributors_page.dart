import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_link.dart';
import 'package:flutter_app/src/util/open_utils.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/section_empty_state.dart';
import 'package:flutter_app/ui/components/shimmer/list_skeleton.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:github/github.dart';

class ContributorsPage extends StatelessWidget {
  final github = GitHub();
  final repositorySlug =
      RepositorySlug(AppLink.githubOwner, AppLink.githubName);

  ContributorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: baseAppbar(title: R.current.Contribution),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          SectionHeader(
              icon: LucideIcons.link,
              title: R.current.projectLink,
              first: true),
          Material(
            color: context.tokens.card,
            borderRadius: UIUtils.getBorderRadius(0, 1),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => OpenUtils.launchURL(AppLink.gitHub),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(R.current.github, style: context.text.bodyLarge),
                          const SizedBox(height: 2),
                          Text(
                            AppLink.gitHub,
                            style: context.text.bodySmall?.copyWith(
                                color: context.scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(LucideIcons.externalLink,
                        size: 16, color: context.scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          SectionHeader(icon: LucideIcons.users, title: R.current.Contributors),
          FutureBuilder<List<Contributor>>(
            future:
                github.repositories.listContributors(repositorySlug).toList(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SectionEmptyState(
                  icon: LucideIcons.circleAlert,
                  message: R.current.somethingError,
                );
              }
              if (!snapshot.hasData) {
                return const ListSkeleton(rows: 6);
              }
              final contributorList = snapshot.data!;
              // 一列一塊 Material 加 2px 間隙，跟 App 裡其他清單同一套；
              // 不是一張卡片配分隔線。
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, contributor) in contributorList.indexed) ...[
                    if (i > 0) const SizedBox(height: 2),
                    _ContributorRow(
                      contributor: contributor,
                      index: i,
                      length: contributorList.length,
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ContributorRow extends StatelessWidget {
  const _ContributorRow({
    required this.contributor,
    required this.index,
    required this.length,
  });

  final Contributor contributor;
  final int index;
  final int length;

  @override
  Widget build(BuildContext context) {
    final url = contributor.htmlUrl;
    return Material(
      color: context.tokens.card,
      borderRadius: UIUtils.getBorderRadius(index, length),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: url == null ? null : () => OpenUtils.launchURL(url),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              SizedBox(
                height: 32,
                width: 32,
                child: CachedNetworkImage(
                  imageUrl: contributor.avatarUrl ?? '',
                  imageBuilder: (context, imageProvider) =>
                      CircleAvatar(radius: 16, backgroundImage: imageProvider),
                  errorWidget: (context, url, error) => CircleAvatar(
                    radius: 16,
                    backgroundColor: context.scheme.surfaceContainerHighest,
                    child: Icon(LucideIcons.user,
                        size: 16, color: context.scheme.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(contributor.login ?? '',
                    style: context.text.bodyLarge),
              ),
              if (url != null) ...[
                const SizedBox(width: 12),
                Icon(LucideIcons.externalLink,
                    size: 16, color: context.scheme.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
