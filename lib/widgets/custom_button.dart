import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;
  final Color colorButton;
  final Color colorTitle;

  const CustomButton(
      {Key? key,
        required this.title,
        required this.onPressed,
        required this.colorButton,
        required this.colorTitle})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      width: MediaQuery.of(context).size.width / 2.5,
      // width: 50,
      child: FlatButton(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        onPressed: onPressed,
        color: colorButton,
        child: Text(
          title,
          style: TextStyle(color: colorTitle, fontSize: 16, fontFamily: 'Lato'),
        ),
      ),
    );
  }
}
