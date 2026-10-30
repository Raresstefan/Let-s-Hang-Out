import '../../data/auth/auth_service.dart';

String emailAuthErrorKey(EmailAuthFailure reason) => switch (reason) {
  EmailAuthFailure.invalidEmail => 'auth.email.errors.invalidEmail',
  EmailAuthFailure.invalidCredentials => 'auth.email.errors.invalidCredentials',
  EmailAuthFailure.emailInUse => 'auth.email.errors.emailInUse',
  EmailAuthFailure.weakPassword => 'auth.email.errors.weakPassword',
  EmailAuthFailure.tooManyRequests => 'auth.email.errors.tooManyRequests',
  EmailAuthFailure.network => 'auth.email.errors.network',
  EmailAuthFailure.userDisabled => 'auth.email.errors.userDisabled',
  EmailAuthFailure.providerDisabled => 'auth.email.errors.providerDisabled',
  EmailAuthFailure.sessionExpired => 'auth.email.errors.sessionExpired',
  EmailAuthFailure.unknown => 'auth.email.errors.unknown',
};
