class User < ActiveRecord::Base

  devise :two_factor_authenticatable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  # :login is a virtual attribute for authenticating by either username or email
  # This is in addition to a real persisted field like 'username'
  attr_accessor :login,
                :auth_token

  validates :email, length: { maximum: 254 }
  validates :username, length: { maximum: 50 }
  validate  :email_or_username,
            :email_requirements,
            :username_requirements

  has_many :addresses, dependent: :destroy
  has_many :user_read_announcements, dependent: :destroy
  has_many :tokens, dependent: :destroy

  has_one_time_password

  after_create :send_welcome_email
  before_save :update_email_hash

  # Used for allowing username or email address for registration with Devise
  def self.find_first_by_auth_conditions(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      where(conditions).where(["lower(username) = :value OR lower(email) = :value", { :value => login.downcase }]).first
    else
      where(conditions).first
    end
  end

  def display_name
    self.username.present? ? self.username : self.email
  end

  # So Devise knows this field is optional
  def email_required?
    false
  end

  def generate_auth_token
    t = SecureRandom.urlsafe_base64(32)
    token = tokens.create(
      token: t,
      provider: :balances_mobile,
      provider_uid: self.id
    )
    self.auth_token = token.token
  end

  def generate_email_hash
    if self.email.present?
      Digest::MD5.hexdigest(self.email + ENV['EMAIL_HASH_SALT'])
    end
  end

  def need_two_factor_authentication?(request)
    self.has_two_factor_enabled && self.email.present?
  end

  def send_two_factor_authentication_code
    # NOTE: If we want to implement sending a text message code, we can do that here.
  end

  def send_welcome_email
    UserMailer.welcome(self.id).deliver if self.email.present?
  end

  private

  def email_or_username
    if self.email.blank? && self.username.blank?
      errors.add(:base, 'Email or username is required')
    end
  end

  def email_requirements
    if self.email.present? && self.email.length > 0 && self.email.length < 5
      errors.add(:email, 'is too short (minimum is 5 characters)')
    end
  end

  def username_requirements
    if self.username.present? && self.username.length > 0
      if (new_record? && User.where("lower(username) = ?", self.username.downcase).any?) ||
         (!new_record? && User.where("lower(username) = ? AND id != ?", self.username.downcase, self.id).any?)

        errors.add(:username, 'is already taken')
      end
    end
  end

  def update_email_hash
    if self.email.present? && self.email_hash != (new_email_hash = generate_email_hash)
      self.email_hash = new_email_hash
    end
  end

end
