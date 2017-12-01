module SalesforceClient
  class << self
    def __client
      @client ||= Restforce.new(host: ENV["SALESFORCE_HOST"])
    end
    def method_missing(method, *args, &block)
      __client.send(method, *args, &block)
    end
  end
end
