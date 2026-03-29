'use client';

import { validatePassword } from '@/lib/passwordValidator';
import { Check, X } from 'lucide-react';

interface PasswordStrengthIndicatorProps {
  password: string;
}

export function PasswordStrengthIndicator({ password }: PasswordStrengthIndicatorProps) {
  const validation = validatePassword(password);

  if (!password) {
    return null;
  }

  return (
    <div className="space-y-2 mt-3 p-3 rounded-lg" style={{ backgroundColor: 'rgba(45, 45, 45, 0.05)' }}>
      <p className="text-xs font-semibold" style={{ color: '#2D2D2D' }}>
        Password Requirements:
      </p>
      <div className="space-y-1 text-xs">
        <RequirementRow
          met={validation.requirements.hasLowercase}
          label="At least one lowercase letter (a-z)"
        />
        <RequirementRow
          met={validation.requirements.hasUppercase}
          label="At least one uppercase letter (A-Z)"
        />
        <RequirementRow
          met={validation.requirements.hasDigit}
          label="At least one number (0-9)"
        />
        <RequirementRow
          met={validation.requirements.hasSymbol}
          label="At least one special character (!@#$%^&*)"
        />
        <RequirementRow
          met={validation.requirements.isMinLength}
          label={`At least 8 characters (${password.length}/8)`}
        />
      </div>
    </div>
  );
}

function RequirementRow({ met, label }: { met: boolean; label: string }) {
  return (
    <div className="flex items-center gap-2">
      {met ? (
        <Check size={16} style={{ color: '#059669' }} />
      ) : (
        <X size={16} style={{ color: '#DC2626' }} />
      )}
      <span style={{ color: met ? '#059669' : '#6B7280' }}>{label}</span>
    </div>
  );
}
