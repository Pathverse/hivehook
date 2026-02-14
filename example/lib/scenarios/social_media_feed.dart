import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hivehook/hivehook.dart';
import '../main.dart';
import 'scenario.dart';

class SocialMediaFeedScenario extends Scenario {
  @override
  String get name => 'Social Media Feed';

  @override
  String get description =>
      'Posts with reactions, comments, nested replies and user interactions';

  @override
  IconData get icon => Icons.forum;

  @override
  List<String> get tags => ['nested', 'lists', 'relationships'];

  @override
  Future<void> run(LogCallback log) async {
    final hive = await HHive.create('demo');

    // Create user profiles
    final users = <String, Map<String, dynamic>>{
      'user_alice': {
        'id': 'user_alice',
        'username': 'alice_dev',
        'displayName': 'Alice Chen',
        'verified': true,
        'bio': 'Senior Software Engineer | Flutter enthusiast 💙',
        'stats': {'followers': 12500, 'following': 342, 'posts': 156},
        'badges': ['verified', 'top_contributor', 'early_adopter'],
      },
      'user_bob': {
        'id': 'user_bob',
        'username': 'bob_coder',
        'displayName': 'Bob Wilson',
        'verified': false,
        'bio': 'Learning Flutter one widget at a time 🚀',
        'stats': {'followers': 890, 'following': 123, 'posts': 45},
        'badges': ['early_adopter'],
      },
      'user_carol': {
        'id': 'user_carol',
        'username': 'carol_designs',
        'displayName': 'Carol Martinez',
        'verified': true,
        'bio': 'UX Designer | Making apps beautiful ✨',
        'stats': {'followers': 25000, 'following': 567, 'posts': 234},
        'badges': ['verified', 'influencer'],
      },
    };

    log('Creating ${users.length} user profiles...');
    for (final entry in users.entries) {
      await hive.put('users/${entry.key}', entry.value);
      final user = entry.value;
      final stats = user['stats'] as Map<String, dynamic>;
      log('  @${user['username']} (${stats['followers']} followers)',
          level: LogLevel.data);
    }
    log('✓ Users stored', level: LogLevel.success);

    // Create a complex post with nested interactions
    final post = <String, dynamic>{
      'id': 'post_${DateTime.now().millisecondsSinceEpoch}',
      'author': 'user_alice',
      'content': <String, dynamic>{
        'text':
            'Just released my new Flutter package for state management! 🎉\n\nIt uses a hook-based architecture that makes reactive programming a breeze.',
        'media': <Map<String, dynamic>>[
          {
            'type': 'image',
            'url': 'https://example.com/package_demo.gif',
            'alt': 'Package demo animation',
            'dimensions': {'width': 800, 'height': 600},
          },
        ],
        'mentions': ['@flutter_dev', '@dart_lang'],
        'hashtags': ['flutter', 'dart', 'opensource'],
      },
      'createdAt': DateTime.now()
          .subtract(const Duration(hours: 3))
          .millisecondsSinceEpoch,
      'visibility': 'public',
      'reactions': <String, List<String>>{
        'like': ['user_bob', 'user_carol', 'user_david', 'user_eve'],
        'love': ['user_carol', 'user_frank'],
        'celebrate': ['user_bob', 'user_george', 'user_helen'],
        'insightful': ['user_ivan'],
      },
      'reactionCount': 10,
      'shareCount': 23,
      'bookmarkCount': 45,
      'comments': <Map<String, dynamic>>[
        {
          'id': 'comment_1',
          'author': 'user_bob',
          'text': 'This looks amazing! How does it compare to Riverpod?',
          'createdAt': DateTime.now()
              .subtract(const Duration(hours: 2, minutes: 45))
              .millisecondsSinceEpoch,
          'reactions': <String, List<String>>{
            'like': ['user_alice', 'user_carol'],
          },
          'replies': <Map<String, dynamic>>[
            {
              'id': 'reply_1_1',
              'author': 'user_alice',
              'text': 'Great question! It\'s more focused on persistence.',
              'createdAt': DateTime.now()
                  .subtract(const Duration(hours: 2, minutes: 30))
                  .millisecondsSinceEpoch,
              'reactions': <String, List<String>>{
                'like': ['user_bob'],
                'helpful': ['user_bob', 'user_carol'],
              },
            },
            {
              'id': 'reply_1_2',
              'author': 'user_bob',
              'text': 'Oh that\'s perfect! I\'ll definitely try it.',
              'createdAt': DateTime.now()
                  .subtract(const Duration(hours: 2, minutes: 15))
                  .millisecondsSinceEpoch,
              'reactions': <String, List<String>>{
                'like': ['user_alice'],
              },
            },
          ],
        },
        {
          'id': 'comment_2',
          'author': 'user_carol',
          'text': 'The API design is so clean! 😍',
          'createdAt': DateTime.now()
              .subtract(const Duration(hours: 1, minutes: 30))
              .millisecondsSinceEpoch,
          'reactions': <String, List<String>>{
            'like': ['user_alice', 'user_bob'],
            'love': ['user_alice'],
          },
          'replies': <Map<String, dynamic>>[],
        },
      ],
      'analytics': <String, dynamic>{
        'impressions': 15234,
        'reach': 8901,
        'engagementRate': 0.082,
        'topReferrers': ['search', 'feed', 'profile'],
      },
    };

    log('Creating post with complex interactions...');
    await hive.put('posts/${post['id']}', post);

    final content = post['content'] as Map<String, dynamic>;
    final text = content['text'] as String;
    log('Post: ${text.substring(0, 50)}...', level: LogLevel.data);

    final reactions = post['reactions'] as Map<String, List<String>>;
    log('Reactions:', level: LogLevel.info);
    for (final entry in reactions.entries) {
      log('  ${entry.key}: ${entry.value.length}', level: LogLevel.data);
    }

    final comments = post['comments'] as List<Map<String, dynamic>>;
    log('Comments: ${comments.length}', level: LogLevel.info);
    for (final comment in comments) {
      final replies = comment['replies'] as List<Map<String, dynamic>>;
      final commentText = comment['text'] as String;
      log('  ${comment['author']}: "${commentText.substring(0, 30)}..." (${replies.length} replies)',
          level: LogLevel.data);
    }

    // Read back and verify nested structure
    log('\nReading post back...');
    final retrieved = await hive.get('posts/${post['id']}') as Map<String, dynamic>;

    log('Verifying nested comment replies:', level: LogLevel.info);
    final retrievedComments = retrieved['comments'] as List;
    final firstComment = retrievedComments[0] as Map<String, dynamic>;
    final firstReplies = firstComment['replies'] as List;
    log('  First comment has ${firstReplies.length} replies', level: LogLevel.data);

    for (final reply in firstReplies) {
      final r = reply as Map<String, dynamic>;
      final rText = r['text'] as String;
      log('    ${r['author']}: ${rText.substring(0, 25)}...', level: LogLevel.data);
    }

    // Calculate total interactions
    int totalReactions = 0;
    final retReactions = retrieved['reactions'] as Map<String, dynamic>;
    for (final r in retReactions.values) {
      totalReactions += (r as List).length;
    }

    int totalCommentReactions = 0;
    int totalReplies = 0;
    for (final c in retrievedComments) {
      final comment = c as Map<String, dynamic>;
      final cReactions = comment['reactions'] as Map<String, dynamic>;
      for (final r in cReactions.values) {
        totalCommentReactions += (r as List).length;
      }
      final replies = comment['replies'] as List;
      totalReplies += replies.length;
      for (final reply in replies) {
        final rp = reply as Map<String, dynamic>;
        final rpReactions = rp['reactions'] as Map<String, dynamic>;
        for (final rr in rpReactions.values) {
          totalCommentReactions += (rr as List).length;
        }
      }
    }

    log('\nEngagement summary:', level: LogLevel.success);
    log('  Post reactions: $totalReactions', level: LogLevel.data);
    log('  Comments: ${retrievedComments.length}', level: LogLevel.data);
    log('  Replies: $totalReplies', level: LogLevel.data);
    log('  Comment reactions: $totalCommentReactions', level: LogLevel.data);

    // Verify deep equality
    if (jsonEncode(post) == jsonEncode(retrieved)) {
      log('✓ All nested structures preserved correctly', level: LogLevel.success);
    } else {
      log('✗ Data mismatch in nested structure', level: LogLevel.error);
    }
  }
}
