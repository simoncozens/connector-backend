module SalesforceSerialization
  extend ActiveSupport::Concern

  @@sf_serialize_affiliations = {
    to_salesforce: -> affiliations, updates {
      org1 = affiliations[0]
      if org1
        # Org name is a link, just to be tricksy
        updates["Organization_Website__c"] = org1["website"]
        updates["Title"] = org1["position"]
      end
      if affiliations[1]
        org2 = affiliations[1]
        updates["Org_2_Temp__c"]= org2["organisation"]
        updates["Org_2_Title__c"] = org2["position"]
        updates["Org_2_Website__c"] = org2["website"]
      end
    },
    from_salesforce: -> sf_person, mongo_person {
      mongo_person.affiliatons
    }
  }

  def sf_person
    if salesforce_id
      return SalesforceClient.find("Contact", salesforce_id)
    end
  end

  def to_salesforce
    return if not changed?

    sf_updates = {}
    changed.each do |change|
      sf_opt = Person.fields[change].options[:salesforce]
      if sf_opt.is_a?(String)
        sf_updates[sf_opt] = send(change)
      elsif sf_opt.is_a?(Hash)
        sf_opt[:to_salesforce].call(send(change), sf_updates)
      end
    end

    return if not salesforce_id
    sf_updates["Id"] = salesforce_id
    UpdateSalesforceJob.perform_later(sf_updates)
  end

  included do
    before_save :to_salesforce
  end
end