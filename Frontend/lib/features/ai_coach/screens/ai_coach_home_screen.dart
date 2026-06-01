import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../controllers/ai_coach_controller.dart';
import '../widgets/chat_interface_widget.dart';
import '../widgets/insights_dashboard_widget.dart';
import '../widgets/coach_settings_widget.dart';
import '../models/ai_coach_models.dart';

/// Organize AI Coach Ana Ekranı
/// 3 Tab: Chat | Insights | Settings
class AiCoachHomeScreen extends StatefulWidget {
  const AiCoachHomeScreen({super.key, this.initialSummary});
  final DailySummary? initialSummary;

  @override
  State<AiCoachHomeScreen> createState() => _AiCoachHomeScreenState();
}

class _AiCoachHomeScreenState extends State<AiCoachHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider?>()?.user?.id;

    return ChangeNotifierProvider<AiCoachController>(
      create: (_) => AiCoachController(
        initialSummary: widget.initialSummary,
        userId: userId,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1D1E33),
          elevation: 0,
          title: const Text(
            'AI Koç',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF00D9FF),
            indicatorWeight: 3,
            labelColor: const Color(0xFF00D9FF),
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.chat_rounded, size: 22),
                text: 'Sohbet',
              ),
              Tab(
                icon: Icon(Icons.insights_rounded, size: 22),
                text: 'Analizler',
              ),
              Tab(
                icon: Icon(Icons.settings_rounded, size: 22),
                text: 'Ayarlar',
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(), // Kaydırma ile geçişi engelle
          children: const [
            // Tab 1: Chat Interface
            ChatInterfaceWidget(),

            // Tab 2: Insights Dashboard
            InsightsDashboardWidget(),

            // Tab 3: Coach Settings
            CoachSettingsWidget(),
          ],
        ),
      ),
    );
  }
}
