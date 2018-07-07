import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'dart:async';

import '../Database/Initializers.dart';
import '../Database/Getters.dart';

import '../UI/CategoriesBar.dart';
import '../UI/KidCard.dart';
import '../UI/AccountDrawer.dart';
import '../UI/Menus.dart';

class CheckinPage extends StatefulWidget {
  final DateTime _dt;
  final Map _permissions;
  final String _user;
  final List<String> _schools;

  CheckinPage(this._dt, this._permissions, this._user, this._schools);

  @override
  _CheckinPageState createState() => new _CheckinPageState(_dt, _permissions, _user, _schools);
}

class _CheckinPageState extends State<CheckinPage> {
  final DateTime _dt;

  Map _permissions; // {calendarAccess -> T/F, canEditKids -> T/F, canEditToday -> T/F}
  String _user;
  List<String> _schools;

  bool _canEditToday;
  bool _pickups = true;
  List<String> _categories = [
    'all',
    'all'
  ]; // [0] -> school, [1] -> Kinder/Elementary
  StreamSubscription<QuerySnapshot> _exceptionListener;
  List<KidCard> _kids = [];
  List<KidCard> _filteredKids = [];

  _CheckinPageState(this._dt, this._permissions, this._user, this._schools) {
    if (new DateFormat.yMMMMd('en_US').format(DateTime.now()) ==
        new DateFormat.yMMMMd('en_US').format(_dt)) {
      _canEditToday = _permissions['canEditToday'];
    } else {
      _canEditToday = _permissions['calendarAccess'];
    }
  }

  @override
  void initState() {
    super.initState();

    initializeToday(_dt).then((void v) {
      getKidCards(_dt).then((List<KidCard> gotKids) {
        setState(() {
          _kids = gotKids;
          _kids.sort((a, b) => a.name.compareTo(b.name));
          _filteredKids = _kids;
        });
      });
    });

    _exceptionListener = Firestore.instance
        .collection('calendar')
        .document('exceptions')
        .collection('noPickupDays')
        .snapshots
        .listen((QuerySnapshot doc) {
      if (doc != null) {
        setState(() {
          _pickups = !(doc.documents.where((DocumentSnapshot doc) {
                return doc.documentID ==
                    new DateFormat.yMMMMd('en_US').format(_dt);
              }).length >=
              1);
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _exceptionListener.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        drawer: new AccountDrawer(_permissions, _user, _schools),
        appBar: new AppBar(
            backgroundColor: _pickups ? null : Colors.red,
            centerTitle: true,
            title: new Text(new DateFormat.MMMMEEEEd('en_US').format(_dt)),
            actions: <Widget>[
              /*
              new IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => print('you pressed the search button'),
                  tooltip: 'Search'),
              */
              _canEditToday
                  ? checkinDayPopup(_pickups, _callPickupsCallback)
                  : null,
            ].where((Object o) => o != null).toList()),
        body: new RefreshIndicator(
            onRefresh: _callRefreshCallback,
            child: new ListView(
                padding: new EdgeInsets.only(top: 35.0),
                children: _pickups
                    ? <Widget>[
                        new Padding(padding: new EdgeInsets.only(bottom: 10.0)),
                        _canEditToday
                            ? new CategoriesBar(_categories, _updateCategory, _schools)
                            : null,
                        new Padding(padding: new EdgeInsets.only(bottom: 25.0)),
                        new Wrap(
                            alignment: WrapAlignment.center,
                            direction: Axis.horizontal,
                            children: _filteredKids),
                        new Padding(padding: new EdgeInsets.only(bottom: 30.0))
                      ].where((Object o) => o != null).toList()
                    : <Widget>[
                        new Padding(padding: new EdgeInsets.only(top: 25.0)),
                        new Center(
                            child: new Text("Today is a No-Pickup day",
                                style: new TextStyle(
                                    fontSize: 20.0, color: Colors.black54)))
                      ])));
  }

  void _updateCategory(String update, int categoryIndex) {
    setState(() {
      _categories[categoryIndex] = update;
      _filteredKids = filterKids(_kids);
    });
  }

  List<KidCard> filterKids(List<KidCard> kids) {
    List<KidCard> filtered = kids.where((KidCard kc) {
      if (_categories[0] == 'all' || kc.school == _categories[0]) {
        if (_categories[1] == 'all' || groupGrade(kc.grade) == _categories[1]) {
          return true;
        }
      }
      return false;
    }).toList();
    filtered.sort((a, b) {
      return a.name.compareTo(b.name);
    });
    return filtered;
  }

  String groupGrade(String grade) {
    if (grade == '') return 'elementary';
    try {
      int.parse(grade);
      return 'elementary';
    } catch (FormatException) {
      return 'kinder';
    }
  }

  Future<Null> _callRefreshCallback() async {
    Navigator.pushReplacement(
        context,
        new MaterialPageRoute(
            builder: (context) => new CheckinPage(_dt, _permissions, _user, _schools)));
  }

  void _callPickupsCallback(bool pickups) {
    DocumentReference ref = Firestore.instance
        .collection('calendar')
        .document('exceptions')
        .collection('noPickupDays')
        .document(new DateFormat.yMMMMd('en_US').format(_dt));
    if (pickups)
      ref.delete();
    else
      ref.setData({});
  }
}
