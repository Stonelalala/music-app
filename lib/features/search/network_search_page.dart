import 'package:flutter/material.dart';

import 'search_page.dart';

class NetworkSearchPage extends StatelessWidget {
  const NetworkSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SearchPage(initialScope: SearchScope.network);
  }
}
