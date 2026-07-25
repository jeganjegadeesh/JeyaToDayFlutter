import 'package:flutter/material.dart';

/// Shared navy accent for the date-group calendar badge, used across every
/// "grouped by date" history list (Bills, Give Stock, Return Stock, Cash
/// Payments) so they all look consistent.
const kDateGroupNavy = Color(0xFF14213D);

/// A small navy calendar badge + date label, used as a section header when
/// a history list is grouped by date.
Widget dateGroupHeader(ColorScheme scheme, String dateLabel) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: kDateGroupNavy, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.calendar_today, size: 15, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Text(dateLabel, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: scheme.onSurface)),
      ],
    ),
  );
}

/// Groups [items] under a formatted date key, preserving the input order of
/// both the groups and the items within each group — sort [items] by date
/// (newest first, typically) before calling this so sections come out in
/// the right order.
Map<String, List<T>> groupByDate<T>(
  List<T> items,
  DateTime Function(T item) dateOf,
  String Function(DateTime date) formatDate,
) {
  final map = <String, List<T>>{};
  for (final item in items) {
    final key = formatDate(dateOf(item));
    map.putIfAbsent(key, () => []).add(item);
  }
  return map;
}