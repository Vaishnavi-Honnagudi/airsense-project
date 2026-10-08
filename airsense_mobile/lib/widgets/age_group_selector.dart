import 'package:flutter/material.dart';
import '../models/aqi_utils.dart';

class AgeGroupSelector extends StatelessWidget {
  final String selected;
  final void Function(String) onSelect;

  const AgeGroupSelector({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAE7DE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: ageGroups.map((g) {
          final isActive = g.id == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(g.id),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF2E6E5E) : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  g.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : const Color(0xFF6B7178),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
