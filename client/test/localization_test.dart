import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexbook/core/localization/app_localizations.dart';
import 'package:nexbook/core/network/localized_error.dart';

void main() {
  test('translates validation errors using the response field', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/auth/register'),
      response: Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/auth/register'),
        statusCode: 422,
        data: {
          'error': {
            'code': 'validation_error',
            'field': 'password',
            'minimum': 10,
          }
        },
      ),
    );

    expect(
      localizedError(AppLocalizations(const Locale('vi')), error),
      'Mật khẩu phải có ít nhất 10 ký tự.',
    );
  });

  test('falls back to English for unsupported locales', () {
    expect(
      AppLocalizations(const Locale('fr')).t('signIn'),
      'Sign in',
    );
  });

  test('detects Vietnamese, Chinese, Japanese, and English defaults', () {
    expect(detectDefaultLocale(const [Locale('vi', 'VN')]).languageCode, 'vi');
    expect(detectDefaultLocale(const [Locale('en', 'VN')]).languageCode, 'vi');
    expect(detectDefaultLocale(const [Locale('zh', 'CN')]).languageCode, 'zh');
    expect(detectDefaultLocale(const [Locale('en', 'JP')]).languageCode, 'ja');
    expect(detectDefaultLocale(const [Locale('fr', 'FR')]).languageCode, 'en');
  });

  test('provides Chinese and Japanese translations', () {
    expect(AppLocalizations(const Locale('zh')).t('signIn'), '登录');
    expect(AppLocalizations(const Locale('ja')).t('signIn'), 'ログイン');
  });
}
