import 'dart:async';
import 'package:flutter/material.dart';
import '../services/geocode_service.dart';

class LocationSearchField extends StatefulWidget {
  final String hint;
  final Color dotColor;
  final void Function(double lat, double lon, String name) onSelect;

  const LocationSearchField({
    super.key,
    required this.hint,
    required this.dotColor,
    required this.onSelect,
  });

  @override
  State<LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends State<LocationSearchField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<PlaceResult> _results = [];
  bool _loading = false;
  bool _showResults = false;

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final results = await GeocodeService.searchPlace(query);
        if (!mounted) return;
        setState(() {
          _results = results;
          _showResults = true;
          _loading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _results = [];
          _loading = false;
        });
      }
    });
  }

  void _pick(PlaceResult place) {
    _controller.text = place.name.split(",").take(2).join(",");
    setState(() {
      _showResults = false;
      _results = [];
    });
    FocusScope.of(context).unfocus();
    widget.onSelect(place.lat, place.lon, place.name);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFDAD6C9)),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: widget.dotColor, shape: BoxShape.circle),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    border: InputBorder.none,
                    hintStyle: const TextStyle(color: Color(0xFFA8A398), fontSize: 13.5),
                  ),
                  style: const TextStyle(fontSize: 13.5),
                ),
              ),
              if (_loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        if (_showResults && _results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFDAD6C9)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final r = _results[i];
                return InkWell(
                  onTap: () => _pick(r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFEAE7DE))),
                    ),
                    child: Text(r.name, style: const TextStyle(fontSize: 13)),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
