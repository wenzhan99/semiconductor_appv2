import 'package:equatable/equatable.dart';

enum StepItemType { text, math }

class StepItem extends Equatable {
  final StepItemType type;
  final String value;
  final String latex;

  const StepItem._({
    required this.type,
    required this.value,
    required this.latex,
  });

  const StepItem.text(String value)
      : this._(type: StepItemType.text, value: value, latex: '');

  const StepItem.math(String latex)
      : this._(type: StepItemType.math, value: '', latex: latex);

  @override
  List<Object?> get props => [type, value, latex];
}
