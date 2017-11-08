class UserMailer < ApplicationMailer
  default :from => 'connector@lausanne.org'

  def reset_password_email(user)
    @user = user
    @url  = edit_password_reset_url(@user.reset_password_token)

    mail to: user.email, subject: "Reset your password"
  end
end
