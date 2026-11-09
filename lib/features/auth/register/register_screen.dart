import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/shared_widgets.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: S.registerDisabledTitle,
            subtitle: S.registerDisabledMessage,
            height: 120,
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: PaeColors.divider),
                    boxShadow: [
                      BoxShadow(
                        color: PaeColors.primary.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: PaeColors.warning.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_person_rounded,
                          color: PaeColors.warning,
                          size: 36,
                        ),
                      ),
                      SizedBox(height: 18),
                      Text(
                        S.registerDisabledTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: PaeTypography.fontDisplay,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        S.registerDisabledMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: PaeColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 22),
                      GradientButton(
                        label: S.registerBackToLogin,
                        icon: Icons.arrow_back_rounded,
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRouter.login,
                          (_) => false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
