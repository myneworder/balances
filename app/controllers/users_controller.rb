class UsersController < ApplicationController

  before_filter :authenticate_user!

  def disable_twofactor
    current_user.update_attributes(
      otp_secret_key: nil,
      has_two_factor_enabled: false
    )
    redirect_to settings_path, flash: {email: 'Two-factor authentication disabled.'}
  end

  def enable_twofactor
    if current_user.email.present?
      current_user.update_attributes(
        otp_secret_key: ROTP::Base32.random_base32
      )
      redirect_to users_twofactor_qr_path
    else
      redirect_to settings_path, flash: {email: 'Email address required to enable two-factor authentication.'}
    end
  end

  def twofactor_qr
    @provisioning_uri = current_user.provisioning_uri(current_user.email, issuer: 'Balances.io')
    @qrCode = RQRCode::render_qrcode(
      @provisioning_uri,
      :svg,
      {
        unit: 4
      }
    )
  end

  def twofactor_verify
    if current_user.email.present?
      current_user.update_attributes(
        has_two_factor_enabled: true
      )
      # Store settings page as the return location after successful
      # verification of 2FA.
      store_location_for :user, settings_path
      redirect_to user_two_factor_authentication_path(verifying: 1)
    else
      redirect_to settings_path, flash: {email: 'Email address required to enable two-factor authentication.'}
    end
  end

end