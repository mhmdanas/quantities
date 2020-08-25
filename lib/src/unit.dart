part of 'quantities.dart';

const kilo = UnitPrefix.kilo;

const centi = UnitPrefix.centi;

final Unit meter = Unit.nonDerived(LengthBaseUnit.meter);

final Unit squareMeter = meter * meter;

final Unit gram = Unit.nonDerived(MassBaseUnit.gram);

final Unit second = Unit.nonDerived(TimeBaseUnit.second);

final Unit day = Unit.nonDerived(TimeBaseUnit.day);

final Unit week = Unit.nonDerived(TimeBaseUnit.week);

final Unit month = Unit.nonDerived(TimeBaseUnit.month);

final Unit year = Unit.nonDerived(TimeBaseUnit.year);

class _SameQuantityTupleEquality
    implements Equality<Tuple2<BaseUnit, UnitPrefix>> {
  const _SameQuantityTupleEquality();

  @override
  bool equals(Tuple2<BaseUnit, UnitPrefix> unit1,
          Tuple2<BaseUnit, UnitPrefix> unit2) =>
      unit1.item1.hasSameQuantity(unit2.item1);

  @override
  int hash(Tuple2<BaseUnit, UnitPrefix> unit) => unit.item1.id;

  @override
  bool isValidKey(Object obj) => obj is Tuple2<BaseUnit, UnitPrefix>;
}

class Unit {
  const Unit._(this.unitsUp, this.unitsDown);

  @visibleForTesting
  Unit.nonDerived(BaseUnit baseUnit, [UnitPrefix prefix])
      : unitsUp = [Tuple2(baseUnit, prefix)],
        unitsDown = const [];

  @visibleForTesting
  factory Unit.derived(List<Tuple2<BaseUnit, UnitPrefix>> unitsUp,
      List<Tuple2<BaseUnit, UnitPrefix>> unitsDown) {
    final newUnitsUp = unitsUp.toList();
    final newUnitsDown = unitsDown.toList();

    for (final tuple in unitsUp) {
      if (newUnitsDown.remove(tuple)) {
        newUnitsUp.remove(tuple);
      }
    }

    return Unit._(newUnitsUp, newUnitsDown);
  }

  static const identity = Unit._([], []);

  static Tuple2<BaseUnit, UnitPrefix> _tryParseNonDerived(String string) {
    if (string == '1') {
      return const Tuple2(null, null);
    }

    if (!RegExp(r'^[a-z]+$').hasMatch(string)) {
      return null;
    }

    UnitPrefix prefix;
    var baseUnitString = string;

    switch (baseUnitString[0]) {
      case 'k':
        prefix = kilo;
        baseUnitString = baseUnitString.substring(1);
        break;

      case 'c':
        prefix = centi;
        baseUnitString = baseUnitString.substring(1);
    }

    final baseUnit = BaseUnit.tryParse(baseUnitString);
    if (baseUnit != null) {
      return Tuple2(baseUnit, prefix);
    }

    return null;
  }

  /// Convert [string] to a unit, returning null in case the string couldn't
  /// be parsed.
  ///
  /// This method and [toString()] are *NOT* the opposite of each other. This
  /// is intentionally, since writing a method that can parse the string
  /// returned by [toString()] is not very easy and this method isn't intended
  /// to parse units from the user. Here are the differences:
  /// - [toString()] uses `·` as a multiplication symbol, while this method
  ///   uses `*`.
  /// - [toString()] uses parenthesis sometimes, while this method can't parse
  ///   them.
  /// - [toString()] can print powers, while this method can't parse them. You
  ///   can repeat the units instead.
  @factory
  // ignore: prefer_constructors_over_static_methods
  static Unit tryParse(String string) {
    final tuple = _tryParseNonDerived(string);

    if (tuple != null) {
      if (tuple == const Tuple2(null, null)) {
        return Unit.identity;
      }

      return Unit._([tuple], const []);
    }

    final unitsUp = <Tuple2<BaseUnit, UnitPrefix>>[];
    final unitsDown = <Tuple2<BaseUnit, UnitPrefix>>[];

    final list = string.split(RegExp('(?=[*/])'));

    final firstTuple = _tryParseNonDerived(list[0]);

    if (firstTuple == null) {
      return null;
    }

    unitsUp.add(firstTuple);

    for (final string in list.skip(1)) {
      switch (string[0]) {
        case '/':
          unitsDown.add(_tryParseNonDerived(string.substring(1)));
          break;

        case '*':
          unitsUp.add(_tryParseNonDerived(string.substring(1)));
          break;

        default:
          return null;
      }
    }

    return Unit.derived(unitsUp, unitsDown);
  }

  Tuple2<Unit, double> simplify() {
    final newUnitsUp = unitsUp.toList();
    final newUnitsDown = unitsDown.toList();
    var valueMultiple = 1.0;

    for (final upTuple in unitsUp) {
      if (newUnitsDown.remove(upTuple)) {
        newUnitsUp.remove(upTuple);
        continue;
      }

      final downTuple = newUnitsDown.firstWhere(
        (elem) => upTuple.item1.hasSameQuantity(elem.item1),
        orElse: () => null,
      );

      if (downTuple != null) {
        newUnitsUp.remove(upTuple);
        newUnitsDown.remove(downTuple);
        valueMultiple *= (upTuple.item1.value * (upTuple.item2?.value ?? 1)) /
            (downTuple.item1.value * (downTuple.item2?.value ?? 1));
      }
    }

    return Tuple2(Unit._(newUnitsUp, newUnitsDown), valueMultiple);
  }

  @visibleForTesting
  final List<Tuple2<BaseUnit, UnitPrefix>> unitsUp;

  @visibleForTesting
  final List<Tuple2<BaseUnit, UnitPrefix>> unitsDown;

  Unit get reciprocal => Unit._(unitsDown, unitsUp);

  Unit operator *(Unit that) => Unit.derived(
        [...unitsUp, ...that.unitsUp],
        [...unitsDown, ...that.unitsDown],
      );

  Unit operator /(Unit that) => Unit.derived(
        [...unitsUp, ...that.unitsDown],
        [...unitsDown, ...that.unitsUp],
      );

  Iterable<String> _tupleListToStrings(
      List<Tuple2<BaseUnit, UnitPrefix>> list) sync* {
    final map = <Tuple2<BaseUnit, UnitPrefix>, int>{};

    for (final tuple in list) {
      if (map.containsKey(tuple)) {
        map[tuple]++;
      } else {
        map[tuple] = 1;
      }
    }

    for (final entry in map.entries) {
      final unitString = _unitTupleToString(entry.key);

      switch (entry.value) {
        case 1:
          yield unitString;
          break;

        case 2:
          yield '$unitString²';
          break;

        default:
          throw RangeError(
              'Cannot convert unit with power more than 2 to string');
      }
    }
  }

  String _unitTupleToString(Tuple2<BaseUnit, UnitPrefix> tuple) {
    if (tuple.item2 == null) return tuple.item1.toString();

    return '${tuple.item2}${tuple.item1}';
  }

  @override
  String toString() {
    if (this == identity) {
      return '1';
    }

    final buffer = StringBuffer();

    if (unitsUp.isEmpty) {
      buffer.write('1');
    } else {
      buffer.writeAll(_tupleListToStrings(unitsUp), ' · ');
    }

    if (unitsDown.isNotEmpty) {
      buffer.write(' / ');
      final stringList = _tupleListToStrings(unitsDown).toList(growable: false);

      if (stringList.length == 1) {
        buffer.write(stringList[0]);
      } else {
        buffer.write('(');
        buffer.writeAll(stringList, ' · ');
        buffer.write(')');
      }
    }

    return buffer.toString();
  }

  bool canBeConvertedTo(Unit other) {
    const equality = UnorderedIterableEquality(_SameQuantityTupleEquality());

    return equality.equals(unitsUp, other.unitsUp) &&
        equality.equals(unitsDown, other.unitsDown);
  }

  @override
  int get hashCode {
    const equality = UnorderedIterableEquality<Tuple2<BaseUnit, UnitPrefix>>();

    return runtimeType.hashCode ^ equality.hash(unitsUp) ^ equality.hash(unitsDown);
  }

  @override
  bool operator ==(dynamic that) {
    const equality = UnorderedIterableEquality<Tuple2<BaseUnit, UnitPrefix>>();

    return identical(this, that) ||
        (that is Unit &&
            that.runtimeType == runtimeType &&
            equality.equals(that.unitsUp, unitsUp) &&
            equality.equals(that.unitsDown, unitsDown));
  }
}
