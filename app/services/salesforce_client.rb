module SalesforceClient
  class << self
    def __client
      @client ||= Restforce.new(host: ENV["SALESFORCE_HOST"])
    end
    def method_missing(method, *args, &block)
      __client.send(method, *args, &block)
    end
    def watch
      # Ensure push topic exists, creating it if not
      __client.query("select Id from PushTopic where Name='ContactChanged'").first or __client.create!('PushTopic',
                     ApiVersion: '23.0',
                     Name: 'ContactChanged',
                     Description: 'Notify connector on contact update',
                     #NotifyForOperations: 'All',
                     NotifyForFields: 'All',
                     Query: "select Id from Contact")

      EM.run do
        __client.subscribe 'ContactChanged' do |m|
          op = {type: m["event"]}
          if m.has_key?("sobject")
            op["Id"] = m["sobject"]["Id"]
          end
          yield(op)
        end
      end
    end
  end
end
