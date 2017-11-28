# app/controllers/password_resets_controller.rb
class PasswordResetsController < ApplicationController
  skip_before_filter :verify_authenticity_token

  # request password reset.
  # you get here when the user entered his email in the reset password form and submitted it.
  def create
    @user = Person.where(email: params[:email]).first
    #@user.deliver_reset_password_instructions! if @user
    render :json => { ok:1, notice: 'Instructions have been sent to your email.'}, status: 200, scope:nil
  end

  # This is the reset password form.
  def edit
    @token = params[:id]
    @user = Person.load_from_reset_password_token(params[:id])

    if @user.blank?
      not_authenticated
      return
    end
  end
      
  # PUT     /api/password_resets/:id
  def update
    @token = params[:id]
    @user = Person.load_from_reset_password_token(params[:id])

    if @user.blank?
      not_authenticated
      return
    end

    # the next line makes the password confirmation validation work
    @user.password_confirmation = params[:person][:password_confirmation]
    # the next line clears the temporary token and updates the password
    if @user.change_password!(params[:person][:password])
      # Send them back to the app, ideally.
      render :action => "update"
    else
      render :action => "edit"
    end
  end
end