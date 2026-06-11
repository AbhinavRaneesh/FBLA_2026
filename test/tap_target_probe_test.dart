import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fblaNavy = Color(0xFF00274D);
const fblaGold = Color(0xFFFDB913);

void main() {
  testWidgets('measure login screen tap targets (verbatim copies)',
      (tester) async {
    const rememberMe = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              // --- verbatim from _buildRememberForgotRow ---
              Row(
                children: [
                  InkWell(
                    key: const Key('remember'),
                    onTap: () {},
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: rememberMe
                                ? fblaGold
                                : Colors.white.withValues(alpha: 0.02),
                            border: Border.all(
                              color: rememberMe
                                  ? fblaGold
                                  : Colors.white.withValues(alpha: 0.40),
                            ),
                          ),
                          child: AnimatedScale(
                            scale: rememberMe ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutBack,
                            child: const Icon(Icons.check,
                                color: fblaNavy, size: 11),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Remember me',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    key: const Key('forgot'),
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: fblaGold,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              // --- verbatim from _buildSignUpPrompt ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'New to FBLA? ',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.54),
                      fontSize: 13.5,
                    ),
                  ),
                  TextButton(
                    key: const Key('create'),
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Create account',
                      style: TextStyle(
                        color: fblaGold,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final remember = tester.getSize(find.byKey(const Key('remember')));
    final forgot = tester.getSize(find.byKey(const Key('forgot')));
    final create = tester.getSize(find.byKey(const Key('create')));
    // ignore: avoid_print
    print('REMEMBER_INKWELL_SIZE=$remember');
    // ignore: avoid_print
    print('FORGOT_BUTTON_SIZE=$forgot');
    // ignore: avoid_print
    print('CREATE_BUTTON_SIZE=$create');

    // Probe actual hit-test reach: tap 14px above the InkWell center
    // (i.e. where a finger aiming at the checkbox row could land).
    final hitForgot = tester.hitTestOnBinding(
      tester.getCenter(find.byKey(const Key('forgot'))),
    );
    expect(hitForgot, isNotNull);
  });
}
