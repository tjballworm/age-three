// Whether the player is logged in to the game server, and the login token this browser keeps.

export type AuthStatus =
  /** no game server configured: the game runs on sample data and there is nothing to log in to */
  | 'none'
  /** trying the saved token */
  | 'checking'
  /** show the login screen */
  | 'loggedOut'
  | 'loggedIn';

export const auth = $state({ status: 'none' as AuthStatus });

const TOKEN_KEY = 'age3.token';

// localStorage can be missing or blocked (private windows, strict settings); then logins last one visit.
export function savedToken(): string | null {
  try {
    return localStorage.getItem(TOKEN_KEY);
  } catch {
    return null;
  }
}

export function saveToken(token: string) {
  try {
    localStorage.setItem(TOKEN_KEY, token);
  } catch {
    /* kept for this visit only */
  }
}

export function forgetToken() {
  try {
    localStorage.removeItem(TOKEN_KEY);
  } catch {
    /* nothing saved */
  }
}
