import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/data/repositories/home_repository_impl.dart';
import 'features/home/domain/repositories/home_repository.dart';
import 'features/home/domain/use_cases/get_home_section_use_case.dart';
import 'presentation/main_shell.dart';

void main() {
  runApp(const MiMusicApp());
}

class MiMusicApp extends StatelessWidget {
  const MiMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeRepository homeRepository = HomeRepositoryImpl();
    final getHomeSectionUseCase = GetHomeSectionUseCase(homeRepository);

    return MaterialApp(
      title: 'MiMusic',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      home: MainShell(getHomeSectionUseCase: getHomeSectionUseCase),
    );
  }
}
