import 'package:intl/intl.dart';

final _qtyFormat = NumberFormat('0.##');

extension QtyFormat on num {
  String get qty => _qtyFormat.format(this);
}