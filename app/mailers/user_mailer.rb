class UserMailer < ApplicationMailer
  default from: 'admin@breakdownlab.me'

  def welcome_email(user, temporary_password)
    @user = user
    @player = user.player
    @team = user.team
    @temporary_password = temporary_password
    @login_url = Rails.application.routes.url_helpers.new_user_session_url(host: Rails.application.config.action_mailer.default_url_options[:host])

    mail(
      to: @user.email,
      subject: "BreakDown Lab - Sport CP"
    )
  end
end
