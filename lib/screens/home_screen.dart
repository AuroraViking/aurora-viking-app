// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'forecast_tab.dart';
import 'my_photos_tab.dart';
import 'print_shop_tab.dart';
import 'pickup_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _tabs = <Widget>[
    ForecastTab(),
    MyPhotosTab(),
    PrintShopTab(),
    PickupTab(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _tabs[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.black,
            ],
          ),
          border: Border(
            top: BorderSide(
              color: Colors.tealAccent.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Colors.tealAccent,
          unselectedItemColor: Colors.grey,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.bolt),
              activeIcon: Icon(Icons.bolt),
              label: 'Forecast',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.photo_outlined),
              activeIcon: Icon(Icons.photo),
              label: 'My Photos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.print_outlined),
              activeIcon: Icon(Icons.print),
              label: 'Print Shop',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_bus_outlined),
              activeIcon: Icon(Icons.directions_bus),
              label: 'Pickup',
            ),
          ],
        ),
      ),
    );
  }
}