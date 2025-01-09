import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:maps/screens/signin_screen.dart';
import 'package:maps/screens/signup_screen.dart';
import 'package:maps/util/app_colors.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnBoardScreen extends StatefulWidget {
  const OnBoardScreen({Key? key}) : super(key: key);

  @override
  State<OnBoardScreen> createState() => _OnBoardScreenState();
}

class _OnBoardScreenState extends State<OnBoardScreen> {
  final controller = PageController();
  bool isLastPage = false;
  late double screenWidth;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget buildPage({
    Color? color,
    String? imagePath,
    String? title1,
    String? subtitle,
  }) =>
      Padding(
        padding: EdgeInsets.all(2.h),
        child: OrientationBuilder(builder: (context, orientation) {
          return Container(
              color: color,
              child: orientation == Orientation.portrait
                  ? Column(
                      children: [
                        SizedBox(
                          height: 60.h,
                        ),
                        Image.asset(imagePath!,
                            width: double.infinity, fit: BoxFit.cover),
                        SizedBox(
                          height: 40.h,
                        ),
                        Text(
                          title1!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            // fontFamily: 'Quicksand',
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryText,
                            fontSize: 20.sp,
                          ),
                        ),
                        SizedBox(
                          height: 2.h,
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 4.0.w),
                          child: Text(
                            subtitle!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                // fontFamily: 'Quicksand',
                                fontWeight: FontWeight.w500,
                                color: AppColors.primaryText,
                                fontSize: 14.sp),
                          ),
                        )
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          // color: Colors.green,
                          // height: 25.h,
                          width: screenWidth / 2,
                          child: Image.asset(imagePath!,
                              width: double.infinity, fit: BoxFit.fitHeight),
                        ),

                        Padding(
                          padding: EdgeInsets.only(left: 6.w),
                          child: SizedBox(
                            // color: Colors.red,
                            // height: 25.h,
                            width: MediaQuery.of(context).size.width / 3,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title1!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    // fontFamily: 'Quicksand',
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primaryText,
                                    fontSize: 16.sp,
                                  ),
                                ),
                                SizedBox(
                                  height: 2.h,
                                ),
                                Container(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 4.0.w),
                                  child: Text(
                                    subtitle!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        // fontFamily: 'Quicksand',
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.primaryText,
                                        fontSize: 10.sp),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        // Image.asset(imagePath,
                        //     width: double.infinity, fit: BoxFit.cover),
                      ],
                    ));
        }),
      );

  @override
  Widget build(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.sp),
        child: Container(
          color: Colors.transparent,
          padding: EdgeInsets.only(bottom: 10.h),
          child: PageView(
            controller: controller,
            onPageChanged: (index) {
              setState(() => isLastPage = index == 2);
            },
            children: [
              buildPage(
                color: Colors.white,
                imagePath: 'assets/screen1.png',
                title1: "Lorem ipsum dolor",
                subtitle:
                    "Minim Lorem proident cupidatat enim anim ipsum eu esse esse.",
              ),
              buildPage(
                color: Colors.white,
                imagePath: 'assets/screen2.png',
                title1: "Lorem  dolor",
                subtitle:
                    "Lorem ipsum dolor sit amet consectetur. Sed pellentesque nisl lacus morbi amet mi nisi id amet.",
              ),
              buildPage(
                color: Colors.white,
                imagePath: 'assets/screen3.png',
                title1: "Lorem ipsum ",
                subtitle:
                    "Lorem ipsum dolor sit amet consectetur. Sed pellentesque nisl lacus morbi amet mi nisi id amet. Minim Lorem proident cupidatat enim anim ipsum eu esse esse.",
              ),
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        // color: Colors.red,
        width: screenWidth,
        color: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        height: 220.h,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Align(
              alignment: Alignment.center,
              child: SmoothPageIndicator(
                  controller: controller,
                  count: 3,
                  effect: WormEffect(
                      type: WormType.normal,
                      dotHeight: 10.h,
                      dotWidth: 10.w,
                      spacing: 16,
                      // strokeWidth: 1,
                      dotColor: AppColors.secondary,
                      activeDotColor: AppColors.primary),
                  onDotClicked: ((index) => controller.animateToPage(index,
                      duration: const Duration(microseconds: 500),
                      curve: Curves.easeIn))),
            ),
            SizedBox(
              height: 20.h,
            ),
            !isLastPage
                ? Row(
                    children: [
                      TextButton(
                          onPressed: () {
                            controller.jumpToPage(2);
                          },
                          child: Text(
                            "Skip",
                            style: TextStyle(
                                // fontFamily: 'Quicksand',
                                fontWeight: FontWeight.w500,
                                color: AppColors.dividerGrey,
                                fontSize: 16.sp),
                          )),
                      Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          controller.nextPage(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: EdgeInsets.symmetric(
                              horizontal: 30.w,
                              vertical: 10.h), // Add padding for size
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                10.sp), // Set the radius for rounded corners
                          ),
                        ),
                        child: Text(
                          "Next",
                          style: TextStyle(
                              fontSize: 16.sp, color: AppColors.primaryText),
                        ),
                      ),
                      // SizedBox(
                      //   width: 10.w,
                      // )
                      // TextButton(
                      //     onPressed: () {
                      //       controller.nextPage(
                      //           duration: const Duration(milliseconds: 500),
                      //           curve: Curves.easeInOut);
                      //     },
                      //     child: Text(
                      //       "Next",
                      //       style: TextStyle(
                      //           // fontFamily: 'Quicksand',
                      //           fontWeight: FontWeight.w500,
                      //           color: AppColors.primaryText,
                      //           fontSize: 20.sp),
                      //     )),
                    ],
                  )
                : Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => SignUpScreen()));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: EdgeInsets.symmetric(
                              horizontal: 40.w,
                              vertical: 15.h), // Add padding for size
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                10.sp), // Set the radius for rounded corners
                          ),
                          minimumSize: Size(screenWidth, 50.sp),
                        ),
                        child: Text(
                          'Sign Up',
                          style: TextStyle(
                              fontSize: 16.sp, color: AppColors.primaryText),
                        ),
                      ),
                      SizedBox(
                        height: 12.h,
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => SignInScreen()));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,

                          padding: EdgeInsets.symmetric(
                              horizontal: 40.w,
                              vertical: 15.h), // Add padding for size
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: AppColors.primaryGrey, // Border color
                              width: 1.0.sp, // Border stroke width
                            ),
                            borderRadius: BorderRadius.circular(
                                10.sp), // Set the radius for rounded corners
                          ),
                          minimumSize: Size(screenWidth, 50.sp),
                        ),
                        child: Text(
                          'Already have an account',
                          style: TextStyle(
                              fontSize: 16.sp,
                              color: AppColors.primaryText,
                              fontWeight: FontWeight.w400),
                        ),
                      ),
                    ],
                  ),
            SizedBox(
              height: 20.h,
            ),
          ],
        ),
      ),
    );
  }
}
