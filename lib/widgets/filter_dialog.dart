import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FilterDialog extends StatefulWidget {
  final String title;
  final List<FilterOption> quickFilters;
  final VoidCallback onReset;
  final void Function(int value, String unit) onCustomDuration;

  const FilterDialog({
    super.key,
    this.title = "Filter Data",
    required this.quickFilters,
    required this.onReset,
    required this.onCustomDuration,
  });

  static void show(
    BuildContext context, {
    String title = "Filter Data",
    required List<FilterOption> quickFilters,
    required VoidCallback onReset,
    required void Function(int value, String unit) onCustomDuration,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => FilterDialog(
        title: title,
        quickFilters: quickFilters,
        onReset: onReset,
        onCustomDuration: onCustomDuration,
      ),
    );
  }

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  final TextEditingController _controller = TextEditingController();
  String _selectedUnit = "Minutes";
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<List<FilterOption>> _chunkFilters(List<FilterOption> filters, int size) {
    final chunks = <List<FilterOption>>[];
    for (var i = 0; i < filters.length; i += size) {
      chunks.add(filters.sublist(i, i + size > filters.length ? filters.length : i + size));
    }
    return chunks;
  }

  void _applyCustomDuration() {
    final int? value = int.tryParse(_controller.text);

    if (value == null || value <= 0) {
      setState(() => _errorText = "Please enter a valid number");
      return;
    }
    if (_selectedUnit == "Minutes" && value > 60) {
      setState(() => _errorText = "Maximum allowed is 60 minutes");
      return;
    }
    if (_selectedUnit == "Hours" && value > 24) {
      setState(() => _errorText = "Maximum allowed is 24 hours");
      return;
    }
    if (_selectedUnit == "Days" && value > 7) {
      setState(() => _errorText = "Maximum allowed is 7 days");
      return;
    }

    Navigator.pop(context);
    widget.onCustomDuration(value, _selectedUnit);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.title,
        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "Quick Filters",
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 10),

      // ✅ No GridView — uses Rows instead
      ...(_chunkFilters(widget.quickFilters, 2).map((rowFilters) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: rowFilters.map((filter) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  filter.onTap();
                },
                child: Text(filter.label),
              ),
            ),
          )).toList(),
        ),
      ))).toList(),

      const SizedBox(height: 20),
      const Text(
        "Custom Duration",
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        onChanged: (_) {
          if (_errorText != null) setState(() => _errorText = null);
        },
        decoration: InputDecoration(
          labelText: "Enter value",
          border: const OutlineInputBorder(),
          errorText: _errorText,
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _selectedUnit,
        items: ["Minutes", "Hours", "Days"]
            .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
            .toList(),
        onChanged: (value) => setState(() => _selectedUnit = value!),
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
    ],
  ),
),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onReset();
          },
          child: const Text("Reset"),
        ),
        ElevatedButton(
          onPressed: _applyCustomDuration,
          child: const Text("Apply"),
        ),
      ],
    );
  }
}

// Simple model to hold each quick filter button
class FilterOption {
  final String label;
  final VoidCallback onTap;

  const FilterOption({required this.label, required this.onTap});
}