module PushNotifications
  extend ActiveSupport::Concern

  def register_device(device)
    d = devices || {}
    d[device["uuid"]] = device
    self.devices = d
    save!
  end

  def notify(alert, data={})
    devices.each {|k,d|
      if d["platform"] == "iOS"
        self.notify_ios(d,alert,data)
      end
    }
  end

  def notify_ios(device, alert, data)
    n = Rpush::Apns::Notification.new
    n.app = Rpush::Apns::App.where(name: "ios_app").first
    n.device_token = device["token"] # 64-character hex string
    n.badge = data[:badge] if data.key?(:badge)
    n.sound = data[:sound] if data.key?(:sound)
    n.category = data[:category] if data.key?(:category)
    n.alert = alert
    n.data = data
    n.save!
  end
end