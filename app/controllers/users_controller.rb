class UsersController < ApplicationController

  before_filter :authenticate_user!

  respond_to :json, only: [:show, :update]

  def index
    redirect_to root_url
  end

  def show
    if params[:id].present? && params[:id].to_i == current_user.id
      @user = current_user
    end

    respond_with @user
  end

  def update
    if params[:id].present? && params[:id].to_i == current_user.id
      @user = current_user
      @user.update_attributes user_params
    end

    respond_with @user
  end

  def disable_twofactor
    current_user.update_attributes(
      otp_secret_key: nil,
      has_two_factor_enabled: false
    )
    UserMailer.twofactor_disabled(current_user.id).deliver
    redirect_to settings_path, flash: {email: 'Two-factor authentication disabled.'}
  end

  def enable_twofactor
    if current_user.email.present?
      current_user.update_attributes(
        otp_secret_key: ROTP::Base32.random_base32
      )
      redirect_to twofactor_qr_users_path
    else
      redirect_to settings_path, flash: {email: 'Email address required to enable two-factor authentication.'}
    end
  end

  def twofactor_qr
    if params[:rescan].present?
      current_user.update_attributes(has_two_factor_enabled: false)
    end

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
      current_user.update_attributes(has_two_factor_enabled: true)

      # Store settings page as the return location after successful
      # verification of 2FA.
      store_location_for :user, settings_path(tfa_success: 1)

      redirect_to user_two_factor_authentication_path(verifying: 1)
    else
      redirect_to settings_path, flash: {email: 'Email address required to enable two-factor authentication.'}
    end
  end

  def unsubscribe
    @user = User.find_by_email_hash(params[:email_hash])
    redirect_to root_path unless @user
  end

  def unsubscribe_confirm
    @user = User.find_by_email_hash(params[:email_hash])

    if @user
      @user.update_attributes(is_subscribed: false)
    else
      redirect_to root_path
    end
  end

  private

  def user_params
    params.require(:user).permit(
      :last_selected_fiat,
      :last_selected_conversion,
    )
  end

end
