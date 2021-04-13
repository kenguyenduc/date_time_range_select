import 'package:flutter/material.dart';

/// UI Tag chọn Hôm nay, Hôm qua, Tháng này, ...
class TagTimeView extends StatelessWidget {
  final String title;
  final GestureTapCallback onTap;
  final bool isSelected;

  const TagTimeView(
      {Key? key,
        required this.title,
        required this.onTap,
        required this.isSelected})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.only(top: 10, bottom: 10, left: 21, right: 21),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? Color(0xFF28A745) : Colors.white,
            border: Border.all(
              color: Color(0xFFE9EDF2),
              width: 1,
            )),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: isSelected ? Colors.white : Color(0xFF5A6271),
              fontSize: 17,
              fontFamily: 'Lato'),
        ),
      ),
    );
  }
}
