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
      mongo_person.affiliations = [
        {organisation: "XXX", website: sf_person["Organization_Website__c"], position: sf_person["Title"]},
        {organisation: sf_person["Org_2_Temp__c"], website: sf_person["Org_2_Website__c"], position: sf_person["Org_2_Website__c"]}
      ]
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

  def from_salesforce(sf_user)
    Person.fields.select {|k,f| f.options[:salesforce]}.each do |k,v|
      sf_opt = v.options[:salesforce]
      if sf_opt.is_a?(String)
        write_attribute(k, sf_user[sf_opt])
      elsif sf_opt.is_a?(Hash)
        sf_opt[:from_salesforce].call(sf_user, self)
      end
    end
  end

  included do
    before_save :to_salesforce
  end

  class_methods do
    def new_from_salesforce(id)
      p = Person.new
      p.salesforce_id = id
      p.from_salesforce(p.sf_person)
      p.password = p.password_confirmation = SecureRandom.uuid # XXX?
      Person.skip_callback(:save, :before, :to_salesforce)
      p.save
      Person.set_callback(:save, :before, :to_salesforce)
      return p
    end
  end
end