class ApplicationController < ActionController::Base
  protect_from_forgery with: :null_session # We're authenticated anyway

  def validate_token!
    begin
      TokenProvider.valid?(token)
      return true
    rescue
      render :json => { :error => "Not authorized" }.to_json, scope: nil, :status => 401
      return false
    end
  end
  
  def authenticate!
    validate_token! or return
    payload, header = TokenProvider.valid?(token)
    @current_user = Person.find_by(email: payload['user_email'])
  end

  def current_user
    @current_user ||= authenticate!
  end

  def token
    request.headers['Authorization'].split(' ').last
  end

end
