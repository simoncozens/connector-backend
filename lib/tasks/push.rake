namespace :push do
    desc "Create iOS push notification app registration"
    task :register_ios => :environment do
      app = Rpush::Apns::App.new
      app.name = "ios_app"
      app.environment = Rails.env
      app.certificate = File.read(Rails.env+".pem")
      if not ENV["APNS_CERT_PASSWORD"]
        throw "APNS_CERT_PASSWORD not set"
      end
      app.password = ENV["APNS_CERT_PASSWORD"]
      app.connections = 1
      app.save!
    end
end