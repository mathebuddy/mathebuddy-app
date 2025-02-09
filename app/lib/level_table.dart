/// MatheBuddy - a gamified app for higher math
/// https://mathebuddy.github.io/
/// (c) 2022-2024 by TH Koeln
/// Author: Andreas Schwenk contact@compiler-construction.com
/// Funded by: FREIRAUM 2022, Stiftung Innovation in der Hochschullehre
/// License: GPL-3.0-or-later

library mathe_buddy_app;

import 'package:flutter/material.dart';

import 'package:mathebuddy/mbcl/src/level_item.dart';
import 'package:mathebuddy/mbcl/src/level_item_exercise.dart';
import 'package:mathebuddy/mbcl/src/level_item_table.dart';
import 'package:mathebuddy/mbcl/src/level.dart';

import 'package:mathebuddy/level_item.dart';

Widget generateTable(State state, MbclLevel level, MbclLevelItem item,
    {MbclExerciseData? exerciseData}) {
  var tableData = item.tableData as MbclTableData;
  List<TableRow> rows = [];
  // head
  List<TableCell> headColumns = [];
  for (var columnData in tableData.head.columns) {
    var cell = generateLevelItem(state, level, columnData);
    headColumns.add(TableCell(child: cell));
  }
  rows.add(TableRow(children: headColumns));
  // rows
  for (var rowData in tableData.rows) {
    List<TableCell> columns = [];
    for (var columnData in rowData.columns) {
      var cell = generateLevelItem(state, level, columnData);
      columns.add(TableCell(child: cell));
    }
    rows.add(TableRow(children: columns));
  }
  // create table widget
  return Table(
      border: TableBorder.all(),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: rows);
}
