# frozen_string_literal: true

# Wraps the signed permanent cookie that holds a list of participant claim
# tokens. A claim token grants access to a specific Participant row across
# devices that share the cookie. Tokens are added when a visitor creates a
# league or claims an open seat; they're never displayed.
class ParticipantClaims
  COOKIE_KEY = :td_claims
  MAX_TOKENS = 100

  def initialize(cookie_jar)
    @cookies = cookie_jar
  end

  def tokens
    raw = @cookies.signed.permanent[COOKIE_KEY]
    Array(raw).select { |t| t.is_a?(String) }
  end

  def include?(token)
    tokens.include?(token)
  end

  def add(token)
    return if token.blank? || include?(token)
    new_tokens = ([token] + tokens).first(MAX_TOKENS)
    @cookies.signed.permanent[COOKIE_KEY] = {value: new_tokens, httponly: true, same_site: :lax}
  end

  def clear
    @cookies.delete(COOKIE_KEY)
  end

  def participant_for(league)
    league.participants.where(claim_token: tokens).first
  end
end
