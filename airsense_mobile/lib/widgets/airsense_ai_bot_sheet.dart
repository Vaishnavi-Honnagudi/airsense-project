import 'package:flutter/material.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

/// Interactive AI Environmental Assistant for Delhi Air Quality & Commute Guidance
class AirSenseAiBotSheet extends StatefulWidget {
  const AirSenseAiBotSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AirSenseAiBotSheet(),
    );
  }

  @override
  State<AirSenseAiBotSheet> createState() => _AirSenseAiBotSheetState();
}

class _AirSenseAiBotSheetState extends State<AirSenseAiBotSheet> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "Namaste! I'm your AirSense Environmental Advisory Guide 📋\n\nI provide hyper-local DPCC guidance, recommend optimal outdoor exercise windows based on diurnal inversion physics, evaluate clean commute corridors, and reference Delhi CAQM GRAP vehicle regulations. How can I help you right now?",
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];

  final List<String> _quickSuggestions = [
    "🏃 Can I jog in Lodhi Garden now?",
    "🚗 Cleanest route from CP to India Gate?",
    "👶 Precautions for children in smog?",
    "🚨 Are BS-IV diesel cars banned today?",
    "🪟 When should I open windows in Delhi?",
    "😷 What mask is best for PM2.5?",
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String query) {
    if (query.trim().isEmpty) return;
    _inputController.clear();

    setState(() {
      _messages.add(ChatMessage(
        text: query,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
    });

    _scrollToBottom();

    // AI response simulation with domain knowledge of Delhi NCR
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final answer = _generateAiResponse(query);
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          text: answer,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _generateAiResponse(String q) {
    final query = q.toLowerCase();

    if (query.contains("jog") || query.contains("run") || query.contains("walk") || query.contains("exercise")) {
      return "🏃 Outdoor Exercise Guidance for Delhi:\n\n"
          "• Recommended Window: Midday (1:00 PM – 4:30 PM). Solar thermal convection lifts ground-level particulates.\n"
          "• High Risk Window: Early morning (5:00 AM – 8:30 AM). Surface temperature inversions trap vehicular exhaust near ground level.\n"
          "• Best Location: Lodhi Garden or Nehru Park (Current AQI ~88, Satisfactory) — 70% cleaner than roadside corridors like Ring Road or Anand Vihar.";
    }

    if (query.contains("route") || query.contains("cp") || query.contains("india gate") || query.contains("drive") || query.contains("travel")) {
      return "🚗 Smart Mobility Route Recommendation:\n\n"
          "• Connaught Place → India Gate:\n"
          "  Take Kasturba Gandhi Marg or Janpath rather than Barakhamba Road.\n"
          "  Route exposure drops from 185 AQI to 132 AQI (28% less PM2.5 inhalation).\n"
          "• Recommended Departure: Leaving after 8:15 PM will save an estimated 22 minutes in traffic delay and 34% pollution exposure.";
    }

    if (query.contains("child") || query.contains("baby") || query.contains("infant") || query.contains("elder") || query.contains("asthma")) {
      return "👶 Sensitive Demographic Advisory (Children & Elderly):\n\n"
          "• Lungs of children inhale 50% more air per pound of body weight than adults.\n"
          "• Keep school commute windows sealed.\n"
          "• Ensure pediatric asthma inhalers are on hand.\n"
          "• Avoid outdoor play near high-density traffic intersections (e.g. ITO, Anand Vihar) during morning rush hour.";
    }

    if (query.contains("grap") || query.contains("car") || query.contains("diesel") || query.contains("bs-iv") || query.contains("ban")) {
      return "🚨 Delhi CAQM GRAP Regulatory Status:\n\n"
          "• Current Regional Status: GRAP Stage II (Very Poor, 301–400 AQI).\n"
          "• Vehicle Rules: Diesel generators are prohibited except for essential services. Higher municipal parking charges apply.\n"
          "• Note: If Delhi enters GRAP Stage III (>400 AQI), BS-III petrol and BS-IV diesel cars are strictly prohibited from plying on NCT Delhi roads with a ₹20,000 fine.";
    }

    if (query.contains("window") || query.contains("ventilat") || query.contains("air purifier")) {
      return "🪟 Home Ventilation Protocols for Delhi:\n\n"
          "• Keep exterior windows firmly closed between 7:30 PM and 9:30 AM (Inversion trap period).\n"
          "• Best ventilation window: 1:30 PM to 4:00 PM when sunshine peaks and wind disperses surface smog.\n"
          "• Run HEPA indoor air purifiers on auto mode in bedrooms overnight.";
    }

    if (query.contains("mask") || query.contains("n95") || query.contains("protect")) {
      return "😷 Particulate Protection Standards:\n\n"
          "• Standard cloth or surgical masks filter less than 20% of toxic PM2.5 aerosols.\n"
          "• Enforce certified N95 or FFP2 respirators with an airtight nose-bridge seal when walking outdoors in Delhi when AQI exceeds 200.";
    }

    return "🤖 AirSense Environmental Telemetry Analysis:\n\n"
        "Delhi's air quality is currently governed by calm north-westerly surface winds (8–12 km/h) and moderate boundary-layer mixing.\n\n"
        "Key recommendations:\n"
        "1. Prioritize indoor activities during morning and evening rush hours.\n"
        "2. If traveling, use AirSense 'Pollution Map' to choose routes avoiding the Anand Vihar and Wazirpur smog corridors.\n"
        "3. Consider visiting South Delhi green corridors (Lodhi Garden, Nehru Park) for clean outdoor air.";
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.menu_book_rounded, color: Color(0xFF38BDF8), size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "AirSense Advisory Guide",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 16),
                              ],
                            ),
                            Text(
                              "Expert Environmental Guidance for Delhi NCR",
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Chat Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length && _isTyping) {
                  return _buildTypingIndicator();
                }
                final msg = _messages[i];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // Quick Suggestion Chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _quickSuggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final s = _quickSuggestions[i];
                return ActionChip(
                  label: Text(
                    s,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                  backgroundColor: const Color(0xFFF1F5F9),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  onPressed: () => _sendMessage(s),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Input Bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _inputController,
                      onSubmitted: _sendMessage,
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                      decoration: const InputDecoration(
                        hintText: "Ask about Delhi air, clean routes, workout hours...",
                        hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                    onPressed: () => _sendMessage(_inputController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isUser) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology_rounded, size: 14, color: Color(0xFF38BDF8)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: msg.isUser ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: msg.isUser ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 13,
                  color: msg.isUser ? Colors.white : const Color(0xFF1E293B),
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (msg.isUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF0284C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, size: 14, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology_rounded, size: 14, color: Color(0xFF38BDF8)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.8, color: Color(0xFF0284C7)),
                ),
                SizedBox(width: 8),
                Text(
                  "AirSense AI is thinking…",
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
