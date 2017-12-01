class UpdateSalesforceJob < ActiveJob::Base
  queue_as :default

  def perform(*args)
    SalesforceClient.update("Contact", *args)
  end
end
