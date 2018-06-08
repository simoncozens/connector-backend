class ApplicationController < ActionController::Base
  protect_from_forgery with: :null_session # We're authenticated anyway
  skip_before_action :verify_authenticity_token

  rescue_from StandardError do |exception|
    # Handle only JSON requests
    raise unless request.format.json?

    err = {error: exception.message}

    err[:backtrace] = exception.backtrace.select do |line|
      # filter out non-significant lines:
      %w(/gems/ /rubygems/ /lib/ruby/).all? do |litter|
         not line.include?(litter)
      end
    end if Rails.env.development? and exception.is_a? Exception

    # duplicate exception output to console:
    STDERR.puts ['ERROR:', err[:error], '']
                    .concat(err[:backtrace] || []).join "\n"

    render :json => err, :status => 500
  end

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

  def authenticate_as_admin!
    if !current_user.is_admin?
      render :json => { :error => "Not authorized" }.to_json, scope: nil, :status => 401
      return false
    end
  end

  def current_user
    @current_user ||= authenticate!
  end

  def token
    request.headers['Authorization'].split(' ').last
  end

end
