/**
 * Password validation rules:
 * - At least one lowercase letter
 * - At least one uppercase letter
 * - At least one digit
 * - At least one special character/symbol
 * - Minimum 8 characters recommended (Supabase default)
 */

export interface PasswordValidationResult {
  valid: boolean;
  errors: string[];
  requirements: {
    hasLowercase: boolean;
    hasUppercase: boolean;
    hasDigit: boolean;
    hasSymbol: boolean;
    isMinLength: boolean;
  };
}

const LOWERCASE_REGEX = /[a-z]/;
const UPPERCASE_REGEX = /[A-Z]/;
const DIGIT_REGEX = /\d/;
const SYMBOL_REGEX = /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/;
const MIN_LENGTH = 8;

export function validatePassword(password: string): PasswordValidationResult {
  const errors: string[] = [];

  const hasLowercase = LOWERCASE_REGEX.test(password);
  const hasUppercase = UPPERCASE_REGEX.test(password);
  const hasDigit = DIGIT_REGEX.test(password);
  const hasSymbol = SYMBOL_REGEX.test(password);
  const isMinLength = password.length >= MIN_LENGTH;

  if (!hasLowercase) {
    errors.push('Password must contain at least one lowercase letter');
  }
  if (!hasUppercase) {
    errors.push('Password must contain at least one uppercase letter');
  }
  if (!hasDigit) {
    errors.push('Password must contain at least one digit');
  }
  if (!hasSymbol) {
    errors.push('Password must contain at least one special character');
  }
  if (!isMinLength) {
    errors.push(`Password must be at least ${MIN_LENGTH} characters long`);
  }

  return {
    valid: errors.length === 0,
    errors,
    requirements: {
      hasLowercase,
      hasUppercase,
      hasDigit,
      hasSymbol,
      isMinLength,
    },
  };
}
