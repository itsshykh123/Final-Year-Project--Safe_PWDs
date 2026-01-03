import 'package:flutter/material.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Alerts',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Featured News Cards
                    SizedBox(
                      height: 200,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _buildFeaturedCard(
                            'https://images.unsplash.com/photo-1504711434969-e33886168f5c?w=400',
                            'Headlines',
                            'Lorem ipsum dolor sit amet consectetur nulla eget tellus mollis non blandit quis in...',
                            isBreaking: true,
                          ),
                          const SizedBox(width: 12),
                          _buildFeaturedCard(
                            'https://images.unsplash.com/photo-1504711434969-e33886168f5c?w=400',
                            'Headlines',
                            'Lorem ipsum dolor sit amet consectetur nulla eget tellus mollis non blandit quis in...',
                            isBreaking: true,
                          ),
                          const SizedBox(width: 12),
                          _buildFeaturedCard(
                            'https://images.unsplash.com/photo-1504711434969-e33886168f5c?w=400',
                            'Headlines',
                            'Lorem ipsum dolor sit amet consectetur nulla eget tellus mollis non blandit quis in...',
                            isBreaking: true,
                          ),
                          const SizedBox(width: 12),
                          _buildFeaturedCard(
                            'https://images.unsplash.com/photo-1476231790875-69f00dbfe29e?w=400',
                            'Headlines',
                            'Nulla eget tellus mollis eget tellus',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Recent Alerts Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Alerts',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: Text(
                              'View More >',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Recent News List
                    _buildNewsListItem(
                      'https://images.unsplash.com/photo-1499856871958-5b9627545d1a?w=400',
                      'Alert News',
                      'Lorem ipsum dolor sit amet consectetur. Mollis ante lorem etiam gravida diam gravi...',
                      isTopNews: true,
                    ),
                    _buildNewsListItem(
                      'https://images.unsplash.com/photo-1495616811223-4d98c6e9c869?w=400',
                      'Alert News',
                      'Lorem ipsum dolor sit amet consectetur. Mollis ante lorem etiam gravida diam gravi...',
                    ),
                    _buildNewsListItem(
                      'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400',
                      'Alert News',
                      'Lorem ipsum dolor sit amet consectetur. Mollis ante lorem etiam gravida diam gravi...',
                    ),
                    _buildNewsListItem(
                      'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400',
                      'Alert News',
                      'Lorem ipsum dolor sit amet consectetur. Mollis ante lorem etiam gravida diam gravi...',
                    ),
                    _buildNewsListItem(
                      'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=400',
                      'Alert News',
                      'Lorem ipsum dolor sit amet consectetur. Mollis ante lorem etiam gravida diam gravi...',
                    ),
                    _buildNewsListItem(
                      'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400',
                      'Alert News',
                      'Lorem ipsum dolor sit amet consectetur. Mollis ante lorem etiam gravida diam gravi...',
                    ),
                    _buildNewsListItem(
                      'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400',
                      'Alert News',
                      'Lorem ipsum dolor sit amet consectetur. Mollis ante lorem etiam gravida diam gravi...',
                    ),
                    _buildNewsListItem(
                      'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=400',
                      'Alert News',
                      'Lorem ipsum dolor sit amet consectetur. Mollis ante lorem etiam gravida diam gravi...',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(
    String imageUrl,
    String title,
    String subtitle, {
    bool isBreaking = false,
  }) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: NetworkImage(imageUrl),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isBreaking)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Breaking',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsListItem(
    String imageUrl,
    String title,
    String subtitle, {
    bool isTopNews = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              if (isTopNews)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Top News',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400]),
        ],
      ),
    );
  }
}
