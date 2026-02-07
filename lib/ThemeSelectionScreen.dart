// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'ThemeController.dart';

// class ThemeSelectionScreen extends StatelessWidget {
//   final ThemeController themeController = Get.find<ThemeController>();

//   final List<Color> colors = [
//     Colors.blue,
//     Colors.red,
//     Colors.green,
//     Colors.purple,
//     Colors.orange,
//     Colors.pink,
//     Colors.teal,
//   ];

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final isDark = theme.brightness == Brightness.dark;

//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Select Theme Color"),
//         elevation: 0,
//         backgroundColor: Colors.transparent,
//         surfaceTintColor: Colors.transparent,
//         flexibleSpace: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [
//                 theme.colorScheme.primary.withValues(alpha: isDark ? 0.3 : 0.1),
//                 Colors.transparent,
//               ],
//               begin: Alignment.topCenter,
//               end: Alignment.bottomCenter,
//             ),
//           ),
//         ),
//         titleTextStyle: TextStyle(
//           color: isDark ? Colors.white : Colors.black87,
//           fontWeight: FontWeight.w600,
//           fontSize: 20,
//         ),
//         iconTheme: IconThemeData(
//           color: isDark ? Colors.white : Colors.black87,
//         ),
//       ),
//       body: Column(
//         children: [
//           // Theme Mode Toggle
//           Container(
//             margin: const EdgeInsets.all(16),
//             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//             decoration: BoxDecoration(
//               color: theme.colorScheme.surfaceContainerHighest
//                   .withValues(alpha: 0.5),
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(
//                 color: theme.colorScheme.outline.withValues(alpha: 0.2),
//               ),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Row(
//                   children: [
//                     Icon(
//                       isDark ? Icons.dark_mode : Icons.light_mode,
//                       color: theme.colorScheme.primary,
//                     ),
//                     const SizedBox(width: 12),
//                     Text(
//                       'Theme Mode',
//                       style: theme.textTheme.titleMedium?.copyWith(
//                         fontWeight: FontWeight.w600,
//                         color: theme.colorScheme.onSurface,
//                       ),
//                     ),
//                   ],
//                 ),
//                 Obx(() => Switch(
//                       value: themeController.isDarkMode.value,
//                       onChanged: (value) {
//                         themeController.toggleTheme();
//                       },
//                       activeColor: theme.colorScheme.primary,
//                       activeTrackColor:
//                           theme.colorScheme.primary.withValues(alpha: 0.3),
//                     )),
//               ],
//             ),
//           ),
//           // Color Selection Title
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             child: Text(
//               'Choose Theme Color',
//               style: theme.textTheme.titleMedium?.copyWith(
//                 fontWeight: FontWeight.w600,
//                 color: theme.colorScheme.onSurface,
//               ),
//             ),
//           ),
//           // Color Grid
//           Expanded(
//             child: GridView.builder(
//               padding: const EdgeInsets.all(16),
//               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 3,
//                 crossAxisSpacing: 10,
//                 mainAxisSpacing: 10,
//               ),
//               itemCount: colors.length,
//               itemBuilder: (context, index) {
//                 return GestureDetector(
//                   onTap: () {
//                     themeController.changeColor(colors[index]);
//                     Get.back();
//                   },
//                   child: Container(
//                     decoration: BoxDecoration(
//                       color: colors[index],
//                       shape: BoxShape.circle,
//                       border: Border.all(
//                         color: theme.colorScheme.outline.withValues(alpha: 0.3),
//                         width: 2,
//                       ),
//                       boxShadow: [
//                         BoxShadow(
//                           color: colors[index].withValues(alpha: 0.3),
//                           blurRadius: 4,
//                           offset: const Offset(0, 2),
//                         ),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
